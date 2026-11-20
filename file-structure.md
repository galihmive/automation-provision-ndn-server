auto-provision-ubuntu24/
├── README.md                          # Dokumentasi cara menjalankan proyek
├── build.ps1                          # Skrip orkestrasi utama di Windows (Packer -> VBox -> Ansible)
│
├── packer/                            # Tahap 1: Pembuatan Golden Image (.ova)
│   ├── ubuntu-24-desktop.pkr.hcl      # Template utama konfigurasi Packer & VirtualBox
│   ├── variables.pkr.hcl              # Definisi variabel (RAM, CPU, ISO URL, user/pass)
│   ├── http/                          # Folder yang di-serve via HTTP oleh Packer saat boot
│   │   ├── meta-data                  # Metadata kosong untuk cloud-init
│   │   └── user-data.pkrtpl.hcl       # Template Subiquity autoinstall dengan hash password saat build
│   └── scripts/                       # Skrip bash yang dijalankan Packer sebelum export OVA
│       ├── setup-base.sh              # Update sistem & instalasi VirtualBox Guest Additions
│       └── cleanup.sh                 # Pembersihan apt cache & machine-id sebelum packaging
│
├── output/                            # Direktori hasil build Golden Image (di-ignore di Git)
│   └── ubuntu-24-desktop-base.ova
│
└── ansible/                           # Tahap 2: Konfigurasi Sistem & Aplikasi (dijalankan via WSL)
    ├── ansible.cfg                    # Konfigurasi default Ansible (host_key_checking = False)
    ├── inventory/
    │   └── hosts.ini                  # Daftar IP/port VM target (misal: 127.0.0.1:2222)
    ├── group_vars/
    │   └── all.yml                    # Variabel global (IP WireGuard, MTU, daftar paket, dll)
    ├── playbooks/
    │   └── site.yml                   # Playbook utama yang memanggil semua roles
    └── roles/                         # Modularisasi konfigurasi
        ├── system_tweaks/             # Pengaturan desktop (anti-sleep, NTP, disable auto-update)
        │   └── tasks/
        │       └── main.yml
        ├── wireguard/                 # Setup VPN & konfigurasi interface wg0
        │   ├── tasks/
        │   │   └── main.yml
        │   └── templates/
        │       └── wg0.conf.j2
        └── custom_apps/               # Instalasi aplikasi target (Chrome .deb, NFD, systemd services)
            ├── tasks/
            │   └── main.yml
            ├── files/
            │   └── custom-routes.sh
            └── templates/
                └── custom-service.service.j2