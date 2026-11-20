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