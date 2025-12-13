# vm-actions
GitHub Actions for building, converting, and packaging VM images with Packer, cloud-init, and QEMU

# About Packer & QEMU

QEMU is a virtual machine, like VirtualBox. Packer is a build tool that automates creation of machine images (VM images, cloud images, and container images). It runs “builders” (for example, QEMU, VMware, VirtualBox, HyperV, Proxmox, AWS, Azure, GCP, Docker) to create a base image, then runs “provisioners” (shell, Ansible, etc.) to configure it, and finally outputs an image artifact.

In this repository, we use Packer to download a source image, boot it using QEMU, provision it using shell and user provided scripts, and finally output a qcow2 image. Currently, it requires a pre-built input image (for example,a barebones Ubuntu "cloud" server image hosted by canonical), but in the future we could expand this to start with an installer image, and then use packer to drive the auto-install (unattended-install).

We assume at the source image has cloud-init and SSH already installed. Packer uses cloud-init to set up host-names, users and passwords, and SSH public keys, and then it uses SSH to remote into the image running in QEMU to detect when it has booted, install packages and settings (provision), and to shut down the VM.

This repository also hosts tools to convert the qcow2 image into formats compatible with virtualbox, proxmox and hyper-v.

# Actions

## provision-vm
todo

## compress-vm
todo

## convert-vm
todo

## package-vm
todo

# Example use
todo

# Multi Stage Pipelines

Chain together these actions to provision the VM in stages. For example... todo