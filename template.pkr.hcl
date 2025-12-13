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
}

variable "build_name" {
  type        = string
  description = "Descriptive name for this build (shown in Packer logs and build metadata)"
  default     = "vm-build"
}

variable "disk_compression" {
  type        = bool
  description = "Enable qcow2 internal compression during Packer compaction (may slow builds)"
  default     = false
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

  memory = 2048
  cpus   = 2

  cd_files = [
    "Packer/cloud_init/user-data",
    "Packer/cloud_init/meta-data",
  ]
  cd_label = "cidata"

  ssh_username         = "packer"
  ssh_private_key_file = "Packer/keys/packer_ed25519"
  ssh_timeout          = "10m"

  shutdown_command = "sudo shutdown -P now"
}

build {
  name    = var.build_name
  sources = ["source.qemu.vm"]

  provisioner "shell" {
    script = var.input_provision_script
  }
}