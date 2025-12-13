packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
  }
}

variable "input_image" {
  type        = string
  description = "URL or path to the input base image (cloud image or existing QCOW2)"
}

variable "output_directory" {
  type        = string
  description = "Directory where the build output will be stored"
}

variable "output_name" {
  type        = string
  description = "Name of the output VM file"
}

variable "input_provision_script" {
  type        = string
  description = "Path to the provisioning script to run"
  default     = null
}

variable "inline_provision_commands" {
  type        = string
  description = "Inline shell commands to run for provisioning (alternative to input_provision_script)"
  default     = null
}

variable "build_name" {
  type        = string
  description = "Descriptive name for this build (shown in Packer logs)"
  default     = "vm-build"
}

variable "disk_compression" {
  type        = bool
  description = "Enable qcow2 internal compression during Packer compaction (may slow builds)"
  default     = false
}

variable "username" {
  type        = string
  description = "Username for the VM user account (used for SSH access during build and for local login on the built VM)"
  default     = "packer"
}

variable "password" {
  type        = string
  description = "Password for the user. You may provide a plain text password or a SHA-512 crypt hash (recommended for security). To generate a compatible hash, use: mkpasswd -m sha-512. See https://cloudinit.readthedocs.io/en/latest/reference/modules.html#set-passwords for details on supported hash formats."
  default     = ""
  sensitive   = true
}

variable "hostname" {
  type        = string
  description = "Hostname for the VM"
  default     = "vm-host"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for authentication"
  default     = ""
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to SSH private key file for Packer to connect"
  default     = "Packer/keys/packer_ed25519"
  sensitive   = true
}

source "qemu" "vm" {
  iso_url      = var.input_image
  iso_checksum = "none"

  disk_image = true
  format     = "qcow2"

  # Enable TRIM/UNMAP propagation (so fstrim can reclaim space in qcow2)
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"

  # qcow2 internal compression during Packer compaction (configurable)
  disk_compression = var.disk_compression

  output_directory = var.output_directory
  vm_name          = var.output_name
  headless         = true

  # Virtual Hardware used when running this image. It can be changed in whatever virtual machine you end up using, this is just the hardware to provision it. 
  memory = 2048
  cpus   = 2

  cd_content = {
    "/user-data" = templatefile("${path.root}/cloud-init/user-data", {
      username       = var.username
      password       = var.password
      hostname       = var.hostname
      ssh_public_key = var.ssh_public_key
    })
    "/meta-data" = templatefile("${path.root}/cloud-init/meta-data", {
      hostname = var.hostname
    })
  }
  cd_label = "cidata"

  ssh_username         = var.username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "10m"

  shutdown_command = "shutdown -P now"
}

build {
  name    = var.build_name
  sources = ["source.qemu.vm"]

  provisioner "shell" {
    script = var.input_provision_script != null && var.input_provision_script != "" ? var.input_provision_script : null
    inline = (var.input_provision_script == null || var.input_provision_script == "") && var.inline_provision_commands != null && var.inline_provision_commands != "" ? [var.inline_provision_commands] : null
  }
}