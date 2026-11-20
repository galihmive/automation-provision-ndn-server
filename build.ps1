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
    $AnsibleCommand = "cd '$WslAnsibleDir' && ansible-playbook -i inventory/hosts.ini playbooks/site.yml"
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
Write-Host " Akses SSH: ssh -p $SshPort ubuntu@127.0.0.1 (password: ubuntu)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
