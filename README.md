# vm-actions
GitHub Actions for building, converting, and packaging VM images with Packer, cloud-init, and QEMU

# About Packer & QEMU

QEMU is a virtual machine, like VirtualBox. Packer is a build tool that automates creation of machine images (VM images, cloud images, and container images). It runs “builders” (for example, QEMU, VMware, VirtualBox, HyperV, Proxmox, AWS, Azure, GCP, Docker) to create a base image, then runs “provisioners” (shell, Ansible, etc.) to configure it, and finally outputs an image artifact.

In this repository, we use Packer to download a source image, boot it using QEMU, provision it using shell and user provided scripts, and finally output a qcow2 image. Currently, it requires a pre-built input image (for example,a barebones Ubuntu "cloud" server image hosted by canonical), but in the future we could expand this to start with an installer image, and then use packer to drive the auto-install (unattended-install).

We assume that the source image has cloud-init and SSH already installed. Packer uses cloud-init to set up host-names, users and passwords, and SSH public keys, and then it uses SSH to remote into the image running in QEMU to detect when it has booted, install packages and settings (provision), and to shut down the VM.

This repository also hosts tools to convert the qcow2 image into formats compatible with virtualbox, proxmox and hyper-v.

All required dependencies (Packer, QEMU, and xorriso) are automatically installed when you use these actions. 

# Actions

## provision-vm

Provisions a VM image using Packer and QEMU. Takes a base cloud image (such as Ubuntu Cloud Images), boots it with cloud-init configuration, and runs provisioning commands or scripts to customize the VM.

### Inputs

- `input_image` (required): URL or path to the input base image (cloud image or existing QCOW2)
- `output_directory` (required): Directory where the build output will be stored
- `output_name` (required): Name of the output VM file
- `build_name` (required): Descriptive name for this build (displayed in Packer logs)
- `input_provision_script` (optional): Path to a provisioning script file to run
- `inline_provision_commands` (optional): Inline shell commands to run for provisioning
- `disk_compression` (optional, default: false): Enable qcow2 internal compression during Packer compaction
- `username` (optional, default: packer): Username for the VM user account
- `password` (optional): Password for the user (plain text or hash from mkpasswd)
- `hostname` (optional, default: vm-host): Hostname for the VM
- `ssh_public_key` (optional): SSH public key for authentication
- `ssh_private_key` (optional): SSH private key content for Packer to connect

**Note**: You must provide either `input_provision_script` OR `inline_provision_commands`, but not both.

## compress-vm
todo

## convert-vm
todo

## package-vm
todo

# Example use

## Example 1: Basic provisioning with inline commands

```yaml
name: Build VM with inline provisioning
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Generate SSH key pair
        run: |
          mkdir -p ~/.ssh
          ssh-keygen -t ed25519 -f ~/.ssh/packer_key -N ""
          echo "SSH_PUBLIC_KEY=$(cat ~/.ssh/packer_key.pub)" >> $GITHUB_ENV
          echo "SSH_PRIVATE_KEY<<EOF" >> $GITHUB_ENV
          cat ~/.ssh/packer_key >> $GITHUB_ENV
          echo "EOF" >> $GITHUB_ENV

      - name: Provision VM
        uses: CraigBuilds/vm-actions/provision-vm@main
        with:
          input_image: 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
          output_directory: './output'
          output_name: 'my-vm.qcow2'
          build_name: 'ubuntu-22.04-custom'
          inline_provision_commands: |
            sudo apt-get update
            sudo apt-get install -y nginx
            sudo systemctl enable nginx
          username: 'ubuntu'
          password: 'ubuntu'
          hostname: 'web-server'
          ssh_public_key: ${{ env.SSH_PUBLIC_KEY }}
          ssh_private_key: ${{ env.SSH_PRIVATE_KEY }}
```

## Example 2: Provisioning with a script file

```yaml
name: Build VM with script provisioning
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Generate SSH key pair
        run: |
          mkdir -p ~/.ssh
          ssh-keygen -t ed25519 -f ~/.ssh/packer_key -N ""
          echo "SSH_PUBLIC_KEY=$(cat ~/.ssh/packer_key.pub)" >> $GITHUB_ENV
          echo "SSH_PRIVATE_KEY<<EOF" >> $GITHUB_ENV
          cat ~/.ssh/packer_key >> $GITHUB_ENV
          echo "EOF" >> $GITHUB_ENV

      - name: Provision VM
        uses: CraigBuilds/vm-actions/provision-vm@main
        with:
          input_image: 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
          output_directory: './output'
          output_name: 'my-vm.qcow2'
          build_name: 'ubuntu-22.04-custom'
          input_provision_script: './scripts/provision.sh'
          username: 'ubuntu'
          hostname: 'custom-vm'
          ssh_public_key: ${{ env.SSH_PUBLIC_KEY }}
          ssh_private_key: ${{ env.SSH_PRIVATE_KEY }}
```

Where `scripts/provision.sh` might contain:

```bash
#!/bin/bash
set -e

# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install common tools
sudo apt-get install -y \
  vim \
  curl \
  git \
  htop

# Configure firewall
sudo ufw allow 22/tcp
sudo ufw --force enable

echo "Provisioning complete!"
```

## Example 3: Multi-step pipeline - building a VM in stages

This example demonstrates how to build a VM in multiple stages within the same job. First, we take a cloud image and install basic utilities, then we take that output and add development tools to it.

```yaml
name: Multi-stage VM build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Generate SSH key pair
        run: |
          mkdir -p ~/.ssh
          ssh-keygen -t ed25519 -f ~/.ssh/packer_key -N ""
          echo "SSH_PUBLIC_KEY=$(cat ~/.ssh/packer_key.pub)" >> $GITHUB_ENV
          echo "SSH_PRIVATE_KEY<<EOF" >> $GITHUB_ENV
          cat ~/.ssh/packer_key >> $GITHUB_ENV
          echo "EOF" >> $GITHUB_ENV

      - name: Stage 1 - Base system with utilities
        uses: CraigBuilds/vm-actions/provision-vm@main
        with:
          input_image: 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
          output_directory: './stage1-output'
          output_name: 'base-vm.qcow2'
          build_name: 'stage1-base-system'
          inline_provision_commands: |
            sudo apt-get update
            sudo apt-get install -y vim curl wget htop
            echo "Stage 1 complete" | sudo tee /etc/stage1-complete
          username: 'ubuntu'
          hostname: 'base-vm'
          ssh_public_key: ${{ env.SSH_PUBLIC_KEY }}
          ssh_private_key: ${{ env.SSH_PRIVATE_KEY }}

      - name: Stage 2 - Add development environment
        uses: CraigBuilds/vm-actions/provision-vm@main
        with:
          input_image: './stage1-output/base-vm.qcow2'
          output_directory: './stage2-output'
          output_name: 'dev-vm.qcow2'
          build_name: 'stage2-dev-environment'
          inline_provision_commands: |
            sudo apt-get update
            sudo apt-get install -y build-essential git
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            node --version
            npm --version
            echo "Stage 2 complete" | sudo tee /etc/stage2-complete
          username: 'ubuntu'
          hostname: 'dev-vm'
          ssh_public_key: ${{ env.SSH_PUBLIC_KEY }}
          ssh_private_key: ${{ env.SSH_PRIVATE_KEY }}

      - name: Upload final VM artifact
        uses: actions/upload-artifact@v4
        with:
          name: dev-vm
          path: ./stage2-output/dev-vm.qcow2
```

# Multi Stage Pipelines

You can chain together multiple provision-vm actions to build VMs in stages, where each stage takes the output from the previous stage and adds more customization. See Example 3 above for a complete multi-step pipeline demonstration.

# Todo

- [ ] Add a fully parameterized packer HCl template
- [ ] Add parameterised "cloud-init" files (user-data and meta-data). The packer template will pass through the parameters to this.
- [ ] SSH keys should come from Gitlab Secrets
- [ ] Add option for inline provisioning scripts
- [ ] Add docker example (pull docker container, boots into it, modifies it from within, commits the new container)
- [ ] Add example CI jobs where the provisioning script is just used to test the container/VM, and not actually add things to it. 