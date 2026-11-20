This file is a merged representation of a subset of the codebase, containing files not matching ignore patterns, combined into a single document by Repomix.

# File Summary

## Purpose
This file contains a packed representation of a subset of the repository's contents that is considered the most important context.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching these patterns are excluded: .env, **/*.md
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Files are sorted by Git change count (files with more changes are at the bottom)

# Directory Structure
```
ansible/
  group_vars/
    all.yml
  inventory/
    hosts.ini
    localhost.ini
  playbooks/
    site.yml
  roles/
    custom_apps/
      files/
        ndn-user-routes.sh
      handlers/
        main.yml
      tasks/
        main.yml
      templates/
        ndn-user-routes.service.j2
    system_tweaks/
      tasks/
        main.yml
    wireguard/
      handlers/
        main.yml
      tasks/
        main.yml
      templates/
        wg0.conf.j2
  ansible.cfg
packer/
  http/
    meta-data
    user-data.pkrtpl.hcl
  scripts/
    cleanup.sh
    setup-base.sh
  ubuntu-24-desktop.pkr.hcl
  variables.pkr.hcl
.gitignore
build.ps1
```

# Files

## File: ansible/group_vars/all.yml
```yaml
---
# Global variables untuk provisioning NDN server
timezone: "Asia/Jakarta"

# SSH Public Key Peneliti (Injeksi ke ~/.ssh/authorized_keys)
researcher_ssh_public_key: ""

# WireGuard VPN Configuration
wireguard_enabled: false
wireguard_interface: "wg0"
wireguard_address: "10.10.10.3/24"
wireguard_mtu: 1420
# Jika dikosongkan, Ansible akan otomatis men-generate keypair di /etc/wireguard/
wireguard_private_key: ""
wireguard_server_public_key: "REPLACE_WITH_SERVER_PUBLIC_KEY"
wireguard_server_endpoint: "vpn.example.com:51820"
wireguard_allowed_ips: "10.10.10.0/24"
wireguard_persistent_keepalive: 25

# NDN & NFD Settings (NFD-nightly apt repo)
install_ndn_stack: true
nfd_nightly_apt_line: "deb [arch=amd64 trusted=yes] https://nfd-nightly-apt.ndn.today/ubuntu noble main"
nfd_packages:
  - nfd
  - ndn-tools

# WebSocket & NDN Permanent Routes
nfd_websocket_port: 9696
ndn_vps_face_uri: "udp4://10.10.10.1"
ndn_vps_face_mtu: 1380

custom_service_name: "ndn-user-routes"
custom_service_enabled: true
```

## File: ansible/inventory/hosts.ini
```ini
# ansible-playbook -i inventory/hosts.ini playbooks/site.yml --ask-pass --ask-become-pass
[ndn_servers]
target_vm ansible_host=127.0.0.1 ansible_port=2222 ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

## File: ansible/inventory/localhost.ini
```ini
# ansible-playbook -i inventory/localhost.ini playbooks/site.yml --ask-become-pass
[ndn_servers]
localhost ansible_connection=local ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

## File: ansible/playbooks/site.yml
```yaml
---
- name: Orchestrate Ubuntu 24 NDN Server Configuration
  hosts: ndn_servers
  become: true
  gather_facts: true

  roles:
    - role: system_tweaks
    - role: wireguard
    - role: custom_apps
```

## File: ansible/roles/custom_apps/files/ndn-user-routes.sh
```bash
#!/usr/bin/env bash
# Route laptop pengguna -> VPS (video /test dan memo /ndn/memo)
VPS="udp4://10.10.10.1"
for i in $(seq 1 30); do nfdc status > /dev/null 2>&1 && break; sleep 1; done
nfdc face create "$VPS" persistency permanent mtu 1380 \
  || nfdc face create "$VPS" persistency permanent
nfdc route add /test "$VPS"
nfdc route add /ndn/memo "$VPS"
```

## File: ansible/roles/custom_apps/handlers/main.yml
```yaml
---
- name: restart nfd
  ansible.builtin.systemd_service:
    name: nfd
    state: restarted
  ignore_errors: true
```

## File: ansible/roles/custom_apps/tasks/main.yml
```yaml
---
# Tasks for role: custom_apps (NFD-nightly, WebSocket & ndn-user-routes)

- name: Add NFD-nightly repository to /etc/apt/sources.list.d/nfd-nightly.list
  ansible.builtin.copy:
    dest: /etc/apt/sources.list.d/nfd-nightly.list
    content: "{{ nfd_nightly_apt_line }}\n"
    owner: root
    group: root
    mode: '0644'
  when: install_ndn_stack

- name: Update apt cache and install nfd & ndn-tools
  ansible.builtin.apt:
    name: "{{ nfd_packages }}"
    state: present
    update_cache: yes
  when: install_ndn_stack

- name: Ensure /etc/ndn/nfd.conf exists from sample if missing
  ansible.builtin.copy:
    src: /etc/ndn/nfd.conf.sample
    dest: /etc/ndn/nfd.conf
    remote_src: true
    force: false
  ignore_errors: true

- name: Ensure WebSocket channel is enabled on port {{ nfd_websocket_port }}
  ansible.builtin.replace:
    path: /etc/ndn/nfd.conf
    regexp: '(?ms)(websocket\s*\{[^}]*?listen\s+)(no|false)'
    replace: '\g<1>yes'
  notify: restart nfd
  ignore_errors: true

- name: Ensure NFD service is enabled and started
  ansible.builtin.systemd_service:
    name: nfd
    state: started
    enabled: true

- name: Deploy /usr/local/bin/ndn-user-routes.sh
  ansible.builtin.copy:
    src: ndn-user-routes.sh
    dest: /usr/local/bin/ndn-user-routes.sh
    owner: root
    group: root
    mode: '0755'

- name: Deploy /etc/systemd/system/ndn-user-routes.service
  ansible.builtin.template:
    src: ndn-user-routes.service.j2
    dest: "/etc/systemd/system/{{ custom_service_name }}.service"
    owner: root
    group: root
    mode: '0644'

- name: Enable and start ndn-user-routes service
  ansible.builtin.systemd_service:
    name: "{{ custom_service_name }}"
    daemon_reload: yes
    state: started
    enabled: true
  when: custom_service_enabled
  ignore_errors: true
```

## File: ansible/roles/custom_apps/templates/ndn-user-routes.service.j2
```jinja
[Unit]
Description=Route NDN laptop pengguna ke VPS
After=nfd.service wg-quick@{{ wireguard_interface }}.service
Requires=nfd.service wg-quick@{{ wireguard_interface }}.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ndn-user-routes.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

## File: ansible/roles/system_tweaks/tasks/main.yml
```yaml
---
# Tasks for role: system_tweaks

- name: Set timezone
  community.general.timezone:
    name: "{{ timezone }}"
  ignore_errors: true

# Paket dasar & pre-seed debconf agar iperf3 tidak berjalan otomatis sebagai daemon
- name: Pre-seed debconf for iperf3 to disable automatic daemon startup
  ansible.builtin.debconf:
    name: iperf3
    question: iperf3/start_daemon
    value: "false"
    vtype: boolean

- name: Install base networking and diagnostic packages
  ansible.builtin.apt:
    name:
      - wireguard
      - openssh-server
      - iperf3
      - curl
      - wget
      - netcat-openbsd
    state: present
    update_cache: yes

- name: Ensure iperf3 service is stopped and disabled
  ansible.builtin.systemd_service:
    name: iperf3
    state: stopped
    enabled: false
  ignore_errors: true

# Unduh & instal Google Chrome .deb di folder Downloads
- name: Ensure Downloads directory exists for {{ ansible_user }}
  ansible.builtin.file:
    path: "/home/{{ ansible_user }}/Downloads"
    state: directory
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
    mode: '0755'

- name: Download Google Chrome stable .deb to ~/Downloads
  ansible.builtin.get_url:
    url: "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    dest: "/home/{{ ansible_user }}/Downloads/google-chrome-stable_current_amd64.deb"
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
    mode: '0644'

- name: Install Google Chrome .deb
  ansible.builtin.apt:
    deb: "/home/{{ ansible_user }}/Downloads/google-chrome-stable_current_amd64.deb"
    state: present

# 10.1 Jangan tidur, jangan layar mati
- name: Disable systemd sleep, suspend, and hibernation
  ansible.builtin.systemd_service:
    name: "{{ item }}"
    masked: true
  loop:
    - sleep.target
    - suspend.target
    - hibernate.target
    - hybrid-sleep.target

- name: Configure GNOME power settings (no sleep, no screen blank)
  ansible.builtin.command: >
    su - {{ ansible_user }} -c "
      dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true;
      dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 || true;
      dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false || true
    "
  ignore_errors: true

# 10.2 Jam tersinkron
- name: Enable NTP time synchronization via timedatectl
  ansible.builtin.command: timedatectl set-ntp true
  changed_when: false

- name: Ensure systemd-timesyncd is started and enabled
  ansible.builtin.systemd_service:
    name: systemd-timesyncd
    state: started
    enabled: true

# 10.3 Pembaruan otomatis dihentikan untuk sesi uji
- name: Stop and disable unattended-upgrades service
  ansible.builtin.systemd_service:
    name: unattended-upgrades
    state: stopped
    enabled: false
  ignore_errors: true

# 11. Akses SSH untuk peneliti
- name: Ensure ssh service is enabled and running
  ansible.builtin.systemd_service:
    name: ssh
    state: started
    enabled: true

- name: Ensure .ssh directory exists for {{ ansible_user }}
  ansible.builtin.file:
    path: "/home/{{ ansible_user }}/.ssh"
    state: directory
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
    mode: '0700'

- name: Inject researcher SSH public key into authorized_keys
  ansible.posix.authorized_key:
    user: "{{ ansible_user }}"
    state: present
    key: "{{ researcher_ssh_public_key }}"
  when: researcher_ssh_public_key | length > 0
```

## File: ansible/roles/wireguard/handlers/main.yml
```yaml
---
- name: restart wireguard
  ansible.builtin.systemd_service:
    name: "wg-quick@{{ wireguard_interface }}"
    state: restarted
    enabled: true
  ignore_errors: true
```

## File: ansible/roles/wireguard/tasks/main.yml
```yaml
---
# Tasks for role: wireguard

- name: Install WireGuard
  ansible.builtin.apt:
    name:
      - wireguard
    state: present
    update_cache: yes
  when: wireguard_enabled

- name: Ensure WireGuard configuration directory exists
  ansible.builtin.file:
    path: /etc/wireguard
    state: directory
    owner: root
    group: root
    mode: '0700'
  when: wireguard_enabled

- name: Generate WireGuard keypair on node if private key not provided
  ansible.builtin.shell: |
    umask 077
    if [ ! -f /etc/wireguard/private.key ]; then
      wg genkey > /etc/wireguard/private.key
      wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
    fi
  args:
    executable: /bin/bash
  when:
    - wireguard_enabled
    - wireguard_private_key | length == 0

- name: Read generated private key if not explicitly set in variables
  ansible.builtin.slurp:
    src: /etc/wireguard/private.key
  register: generated_wg_privkey
  when:
    - wireguard_enabled
    - wireguard_private_key | length == 0

- name: Set effective WireGuard private key fact
  ansible.builtin.set_fact:
    effective_wg_private_key: "{{ wireguard_private_key if (wireguard_private_key | length > 0) else (generated_wg_privkey.content | b64decode | trim) }}"
  when: wireguard_enabled

- name: Deploy WireGuard configuration (/etc/wireguard/wg0.conf)
  ansible.builtin.template:
    src: wg0.conf.j2
    dest: "/etc/wireguard/{{ wireguard_interface }}.conf"
    owner: root
    group: root
    mode: '0600'
  when: wireguard_enabled
  notify: restart wireguard

- name: Enable and start wg-quick@wg0 service
  ansible.builtin.systemd_service:
    name: "wg-quick@{{ wireguard_interface }}"
    enabled: true
    state: started
  when: wireguard_enabled
  ignore_errors: true
```

## File: ansible/roles/wireguard/templates/wg0.conf.j2
```jinja
[Interface]
PrivateKey = {{ effective_wg_private_key }}
Address = {{ wireguard_address }}
MTU = {{ wireguard_mtu }}

[Peer]
# VPS (hub)
PublicKey = {{ wireguard_server_public_key }}
Endpoint = {{ wireguard_server_endpoint }}
AllowedIPs = {{ wireguard_allowed_ips }}
PersistentKeepalive = {{ wireguard_persistent_keepalive }}
```

## File: ansible/ansible.cfg
```ini
[defaults]
inventory          = ./inventory/hosts.ini
roles_path         = ./roles
host_key_checking  = False
retry_files_enabled= False
timeout            = 30

[privilege_escalation]
become             = True
become_method      = sudo
become_user        = root
become_ask_pass    = False
```

## File: packer/http/meta-data
```
instance-id: ubuntu24-desktop-base
local-hostname: ubuntu24-desktop
```

## File: packer/http/user-data.pkrtpl.hcl
```hcl
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        all-en-interfaces:
          match:
            name: "en*"
          dhcp4: true
        all-eth-interfaces:
          match:
            name: "eth*"
          dhcp4: true
  identity:
    hostname: ubuntu24-desktop
    username: ubuntu
    password: "${password_hash}"
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - virtualbox-guest-utils
    - virtualbox-guest-x11
    - curl
    - wget
    - git
    - sudo
  storage:
    layout:
      name: direct
  user-data:
    package_update: true
    package_upgrade: false
    disable_root: false
  late-commands:
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
    - chmod 440 /target/etc/sudoers.d/ubuntu
```

## File: packer/scripts/cleanup.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Membersihkan Sistem Sebelum Export OVA ==="

export DEBIAN_FRONTEND=noninteractive

# Bersihkan apt cache
sudo apt-get autoremove -y
sudo apt-get clean -y
sudo rm -rf /var/lib/apt/lists/*

# Bersihkan machine-id agar VM clone mendapatkan identifier baru
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Bersihkan history bash dan leases DHCP
cat /dev/null > ~/.bash_history && history -c || true
sudo rm -f /var/lib/dhcp/* || true

# Kosongkan sisa free space pada disk untuk efisiensi kompresi OVA
echo "Menulis zero-bytes ke disk kosong..."
sudo dd if=/dev/zero of=/EMPTY bs=1M status=none || true
sudo rm -f /EMPTY

sync
echo "=== Pembersihan Selesai ==="
```

## File: packer/scripts/setup-base.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Memulai Setup Base System Ubuntu 24 Desktop ==="

export DEBIAN_FRONTEND=noninteractive

# Update repository
sudo apt-get update -y

# Pastikan driver Guest Additions dan utilitas esensial terpasang
sudo apt-get install -y --no-install-recommends \
    virtualbox-guest-utils \
    virtualbox-guest-x11 \
    net-tools \
    curl \
    wget \
    software-properties-common

# Konfigurasi GDM/Desktop auto-login untuk kenyamanan desktop server jika diperlukan
if [ -f /etc/gdm3/custom.conf ]; then
    echo "Mengatur konfigurasi GDM..."
    sudo sed -i 's/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/' /etc/gdm3/custom.conf || true
    sudo sed -i 's/#  AutomaticLogin = user1/AutomaticLogin = ubuntu/' /etc/gdm3/custom.conf || true
fi

echo "=== Base Setup Selesai ==="
```

## File: packer/ubuntu-24-desktop.pkr.hcl
```hcl
packer {
  required_version = ">= 1.8.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

source "virtualbox-iso" "ubuntu24_desktop" {
  vm_name          = var.vm_name
  guest_os_type    = "Ubuntu_64"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  headless         = var.headless
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.disk_size
  format           = "ova"
  output_directory = "../output"
  output_filename  = "${var.vm_name}"

  # Serve cloud-init files with the password hash supplied at build time.
  http_content = {
    "meta-data" = file("${path.root}/http/meta-data")
    "user-data" = templatefile("${path.root}/http/user-data.pkrtpl.hcl", {
      password_hash = var.ssh_password_hash
    })
  }

  # Boot command untuk Subiquity autoinstall di Ubuntu 24.04
  boot_wait = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" quiet<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  # SSH Communicator untuk provisioning
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "45m"
  ssh_handshake_attempts = 100
  shutdown_command       = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"],
    ["modifyvm", "{{ .Name }}", "--clipboard-mode", "bidirectional"],
    ["modifyvm", "{{ .Name }}", "--drag-and-drop", "bidirectional"]
  ]
}

build {
  sources = ["source.virtualbox-iso.ubuntu24_desktop"]

  provisioner "shell" {
    scripts = [
      "scripts/setup-base.sh",
      "scripts/cleanup.sh"
    ]
    execute_command = "echo '${var.ssh_password}' | sudo -S -E bash '{{ .Path }}'"
  }
}
```

## File: packer/variables.pkr.hcl
```hcl
variable "iso_url" {
  type        = string
  description = "Path lokal ke file ISO Ubuntu 24.04.4 Desktop"
  default     = "./iso/ubuntu-24.04.4-desktop-amd64.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum SHA256 ISO Ubuntu 24.04.4 Desktop"
  default     = "sha256:3a4c9877b483ab46d7c3fbe165a0db275e1ae3cfe56a5657e5a47c2f99a99d1e"
}

variable "vm_name" {
  type        = string
  description = "Nama VM base"
  default     = "ubuntu-24-desktop-base"
}

variable "cpus" {
  type        = number
  description = "Jumlah CPU core"
  default     = 2
}

variable "memory" {
  type        = number
  description = "Ukuran RAM dalam MB"
  default     = 4096
}

variable "disk_size" {
  type        = number
  description = "Ukuran disk dalam MB"
  default     = 40960
}

variable "ssh_username" {
  type        = string
  description = "Username SSH"
  default     = "ubuntu"
}

variable "ssh_password" {
  type        = string
  description = "Password SSH untuk proses instalasi"
  sensitive   = true
}

variable "ssh_password_hash" {
  type        = string
  description = "Hash SHA-512 untuk password SSH yang sama"
  sensitive   = true
}

variable "headless" {
  type        = bool
  description = "Jalankan Packer dalam mode headless"
  default     = false
}
```

## File: .gitignore
```
# Packer cache & output
output/
packer_cache/
*.ova
*.vmdk
*.vdi

# Ansible retry & log files
ansible/*.retry
*.log

# Sensitive credentials & keys
*.pem
*.key
*.id_rsa
ansible/group_vars/vault.yml
auto-prov-ndn-server.md

# OS / Editor temporary files
.DS_Store
Thumbs.db
.vscode/
.idea/
```

## File: build.ps1
```powershell
<#
.SYNOPSIS
    Skrip orkestrasi otomatis: Packer -> VirtualBox -> Ansible (via WSL)
.DESCRIPTION
    Menjalankan alur penuh atau parsial:
    1. Membangun Golden Image Ubuntu 24 Desktop (.ova) dengan Packer.
    2. Mengimpor dan mengonfigurasi VM di VirtualBox (termasuk port-forwarding SSH).
    3. Menjalankan provisioning Ansible melalui WSL ke VM target.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("all", "packer", "deploy", "ansible", "clean")]
    [string]$Stage = "all",

    [Parameter()]
    [string]$VmName = "Ubuntu-24-NDN-Server",

    [Parameter()]
    [int]$SshPort = 2222,

    [Parameter()]
    [switch]$Headless
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Automated Server Provisioning (Ubuntu 24 Desktop / NDN) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Stage terpilih: $Stage" -ForegroundColor Yellow

# 1. Deteksi VBoxManage
$VBoxManage = "VBoxManage"
if (-not (Get-Command "VBoxManage" -ErrorAction SilentlyContinue)) {
    $DefaultVBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
    if (Test-Path $DefaultVBoxPath) {
        $VBoxManage = $DefaultVBoxPath
    } else {
        Write-Error "VirtualBox (VBoxManage.exe) tidak ditemukan di PATH maupun di '$DefaultVBoxPath'!"
    }
}
Write-Host "[✓] VirtualBox: $VBoxManage" -ForegroundColor Green

# 2. Deteksi Packer
if ($Stage -in @("all", "packer")) {
    if (-not (Get-Command "packer" -ErrorAction SilentlyContinue)) {
        Write-Error "Packer tidak ditemukan di PATH! Pastikan Packer telah diinstal."
    }
    Write-Host "[✓] Packer terdeteksi" -ForegroundColor Green
}

# 3. Deteksi WSL & Ansible
if ($Stage -in @("all", "ansible")) {
    if (-not (Get-Command "wsl" -ErrorAction SilentlyContinue)) {
        Write-Warning "WSL tidak terdeteksi. Ansible membutuhkan WSL pada lingkungan Windows."
    } else {
        Write-Host "[✓] WSL terdeteksi" -ForegroundColor Green
    }
}

# --- STAGE: CLEAN ---
if ($Stage -eq "clean") {
    Write-Host "`n>>> Membersihkan VM '$VmName'..." -ForegroundColor Magenta
    & $VBoxManage controlvm $VmName poweroff 2>$null
    Start-Sleep -Seconds 2
    & $VBoxManage unregistervm $VmName --delete 2>$null
    Write-Host "[✓] VM dibersihkan." -ForegroundColor Green
    return
}

# --- STAGE 1: PACKER BUILD ---
$OvaPath = Join-Path $ProjectRoot "output\ubuntu-24-desktop-base.ova"
if ($Stage -in @("all", "packer")) {
    Write-Host "`n>>> [Tahap 1] Memulai Packer Build..." -ForegroundColor Magenta
    Set-Location (Join-Path $ProjectRoot "packer")
    
    $HeadlessFlag = if ($Headless) { "-var=headless=true" } else { "-var=headless=false" }
    
    & packer init .
    & packer build -force $HeadlessFlag .
    
    Set-Location $ProjectRoot
    if (-not (Test-Path $OvaPath)) {
        Write-Error "File output OVA tidak ditemukan di: $OvaPath"
    }
    Write-Host "[✓] Golden Image OVA berhasil dibuat: $OvaPath" -ForegroundColor Green
}

# --- STAGE 2: DEPLOY VM VIRTUALBOX ---
if ($Stage -in @("all", "deploy")) {
    Write-Host "`n>>> [Tahap 2] Mengimpor OVA ke VirtualBox & Menjalankan VM..." -ForegroundColor Magenta
    
    if (-not (Test-Path $OvaPath)) {
        Write-Error "File OVA tidak ditemukan: $OvaPath. Jalankan tahap 'packer' terlebih dahulu!"
    }

    # Hapus VM lama jika sudah ada
    & $VBoxManage controlvm $VmName poweroff 2>$null
    Start-Sleep -Seconds 1
    & $VBoxManage unregistervm $VmName --delete 2>$null

    # Import OVA
    Write-Host "Mengimpor $OvaPath sebagai VM '$VmName'..."
    & $VBoxManage import $OvaPath --vsys 0 --vmname $VmName

    # Konfigurasi Port Forwarding untuk SSH
    Write-Host "Mengatur NAT Port-Forwarding (Host Port: $SshPort -> Guest Port: 22)..."
    & $VBoxManage modifyvm $VmName --natpf1 "guestssh,tcp,127.0.0.1,$SshPort,,22"

    # Jalankan VM
    $VmType = if ($Headless) { "headless" } else { "gui" }
    Write-Host "Menjalankan VM dalam mode $VmType..."
    & $VBoxManage startvm $VmName --type $VmType

    # Tunggu port SSH aktif
    Write-Host "Menunggu port SSH ($SshPort) siap..." -ForegroundColor Yellow
    $MaxRetries = 40
    $RetryCount = 0
    $PortOpen = $false

    while (-not $PortOpen -and $RetryCount -lt $MaxRetries) {
        Start-Sleep -Seconds 3
        $RetryCount++
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("127.0.0.1", $SshPort)
            $tcp.Close()
            $PortOpen = $true
            Write-Host "`n[✓] SSH port $SshPort telah aktif!" -ForegroundColor Green
        } catch {
            Write-Host -NoNewline "."
        }
    }

    if (-not $PortOpen) {
        Write-Error "Timeout menunggu SSH pada 127.0.0.1:$SshPort. Pastikan VM boot dengan normal."
    }
}

# --- STAGE 3: ANSIBLE PROVISIONING ---
if ($Stage -in @("all", "ansible")) {
    Write-Host "`n>>> [Tahap 3] Menjalankan Ansible Playbook via WSL..." -ForegroundColor Magenta
    
    # Path konversi untuk WSL
    $WslAnsibleDir = (& wsl wslpath -a (Join-Path $ProjectRoot "ansible")).Trim()
    
    Write-Host "WSL Ansible directory: $WslAnsibleDir"
    
    # Eksekusi playbook di WSL
    $AnsibleCommand = "cd '$WslAnsibleDir' && ansible-playbook -i inventory/hosts.ini playbooks/site.yml --ask-pass --ask-become-pass"
    Write-Host "Menjalankan: wsl bash -c `"$AnsibleCommand`"" -ForegroundColor Cyan
    
    & wsl bash -c $AnsibleCommand

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[✓] Provisioning Ansible Berhasil!" -ForegroundColor Green
    } else {
        Write-Warning "Ansible selesai dengan beberapa peringatan/error. Silakan cek output di atas."
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Proses Provisioning Selesai!" -ForegroundColor Green
Write-Host " Akses SSH: ssh -p $SshPort ubuntu@127.0.0.1" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
```
