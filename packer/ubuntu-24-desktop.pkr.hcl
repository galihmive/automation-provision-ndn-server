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
