resource "linode_firewall" "ssh" {
  label           = "${var.label}-ssh"
  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.ssh_allowed_ipv4
    ipv6     = var.ssh_allowed_ipv6
  }
}

resource "linode_instance" "workstation" {
  label                = var.label
  region               = var.region
  type                 = "g2-gpu-rtx4000a1-s"
  firewall_id          = linode_firewall.ssh.id
  interface_generation = "legacy_config"
  backups_enabled      = false
  migration_type       = "cold"
  tags                 = ["ai-dev-box", "gpu", "development"]

  metadata {
    user_data = base64encode(local.cloud_init)
  }
}

# Explicit disks/config ensure the Ubuntu distribution kernel boots, not a
# provider kernel without the matching NVIDIA modules. Fresh deployments only.
resource "linode_instance_disk" "root" {
  linode_id       = linode_instance.workstation.id
  label           = "ubuntu-root"
  size            = 523264
  filesystem      = "ext4"
  image           = "linode/ubuntu26.04"
  root_pass       = var.root_password
  authorized_keys = var.ssh_public_keys
}

resource "linode_instance_disk" "swap" {
  linode_id  = linode_instance.workstation.id
  label      = "swap"
  size       = 1024
  filesystem = "swap"
}

resource "linode_instance_config" "ubuntu" {
  linode_id   = linode_instance.workstation.id
  label       = "ubuntu-grub"
  kernel      = "linode/grub2"
  root_device = "/dev/sda"
  booted      = true

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.root.id
  }
  device {
    device_name = "sdb"
    disk_id     = linode_instance_disk.swap.id
  }
}
