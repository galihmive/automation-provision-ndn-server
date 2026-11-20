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
