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
