# Automation Provisioning NDN Server (Ubuntu 24.04 Desktop)

Proyek otomasi infrastruktur untuk membuat dan mengonfigurasi mesin virtual server Ubuntu 24.04 Desktop pada host **Windows** menggunakan kombinasi **Packer**, **VirtualBox**, dan **Ansible**.

---

## 🏗️ Arsitektur & Alur Kerja

1. **Packer + VirtualBox**:
   - Membangun *Golden Image* (`.ova`) Ubuntu 24.04 secara *unattended* menggunakan Subiquity autoinstall (cloud-init).
   - Menginstal driver VirtualBox Guest Additions dan paket dasar.
   - Melakukan pembersihan (cleanup machine-id, apt cache) dan mengekspor image ke folder `output/`.

2. **VirtualBox Orchestrator (`build.ps1`)**:
   - Mengimpor file OVA hasil build Packer menjadi instance VM baru di VirtualBox.
   - Mengonfigurasi NAT port-forwarding (Host `127.0.0.1:2222` -> Guest `22`).
   - Menyalakan VM (GUI/Headless) dan memonitor hingga port SSH siap menerima koneksi.

3. **Ansible Provisioner (via WSL)**:
   - Dijalankan dari Windows melalui WSL (`wsl ansible-playbook`).
   - Melakukan post-provisioning:
     - **system_tweaks**: Disable screen sleep/lock, setup timezone & NTP.
     - **wireguard**: Konfigurasi interface VPN WireGuard (`wg0`).
     - **custom_apps**: Instalasi stack NDN (Named Data Networking / NFD) dan systemd custom route services.

---

## 📋 Prasyarat Sistem (Windows Host)

Pastikan aplikasi-aplikasi berikut telah terpasang di host Windows Anda:
- **Oracle VirtualBox** (versi 7.x disarankan, terpasang di `C:\Program Files\Oracle\VirtualBox` atau masuk PATH).
- **Packer** (versi >= 1.8.0 di PATH Windows).
- **WSL** (Windows Subsystem for Linux, e.g., Ubuntu/Debian) dengan **Ansible** dan `sshpass` terpasang di dalamnya (`sudo apt install ansible sshpass -y`).
- **PowerShell** 5.1 / 7+.

---

## 📁 Struktur Direktori

```text
├── build.ps1                          # Skrip orkestrasi utama di Windows
├── packer/                            # Tahap 1: Pembuatan Golden Image (.ova)
│   ├── ubuntu-24-desktop.pkr.hcl      # Konfigurasi Packer & VirtualBox builder
│   ├── variables.pkr.hcl              # Variabel ISO, vCPU, RAM, credentials
│   ├── http/                          # HTTP Autoinstall Subiquity (user-data template, meta-data)
│   └── scripts/                       # Shell scripts (setup-base.sh & cleanup.sh)
├── output/                            # Direktori hasil build OVA
└── ansible/                           # Tahap 2: Konfigurasi Sistem & Aplikasi
    ├── ansible.cfg                    # Konfigurasi Ansible (host_key_checking = False)
    ├── inventory/hosts.ini            # Target VM (127.0.0.1:2222)
    ├── group_vars/all.yml             # Variabel global & konfigurasi NDN / VPN
    ├── playbooks/site.yml             # Master playbook
    └── roles/                         # Modular roles: system_tweaks, wireguard, custom_apps
```

---

## 🚀 Cara Menjalankan

Buka **PowerShell** sebagai Administrator atau pengguna normal di direktori proyek:

### 1. Jalankan Seluruh Alur (Packer -> Deploy VM -> Ansible)
```powershell
.\build.ps1 -Stage all
```

### 2. Jalankan Per Tahap (Modular)
- **Hanya Build Golden Image (Packer)**:
  ```powershell
  .\build.ps1 -Stage packer
  ```
- **Hanya Deploy & Nyalakan VM dari OVA yang sudah ada**:
  ```powershell
  .\build.ps1 -Stage deploy
  ```
- **Hanya Jalankan Konfigurasi Ansible**:
  ```powershell
  .\build.ps1 -Stage ansible
  ```
- **Hapus / Bersihkan VM yang berjalan**:
  ```powershell
  .\build.ps1 -Stage clean
  ```

### 3. Opsi Tambahan
- **Mode Headless** (tanpa menampilkan jendela VirtualBox GUI):
  ```powershell
  .\build.ps1 -Stage all -Headless
  ```
- **Kustomisasi Port SSH atau Nama VM**:
  ```powershell
  .\build.ps1 -Stage deploy -VmName "My-NDN-Server" -SshPort 2222
  ```

---

## 🔐 Kredensial & Konfigurasi

- **Username**: `ubuntu`
- Saat build, Packer meminta password SSH dan hash SHA-512 untuk password yang sama. Buat hash dengan:
  ```powershell
  wsl openssl passwd -6
  ```
- Saat provisioning Ansible, masukkan password yang sama ketika diminta untuk SSH dan sudo.
- WireGuard dinonaktifkan secara default. Untuk mengaktifkannya, isi `wireguard_server_public_key` dan `wireguard_server_endpoint` di `ansible/group_vars/all.yml`, lalu set `wireguard_enabled: true`.
- **Port SSH Forwarding**: `2222` secara default.
- **Akses Manual SSH**:
  ```bash
  ssh -p 2222 ubuntu@127.0.0.1
  ```
