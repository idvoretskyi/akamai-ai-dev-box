###############################################################################
# Core resources: the AI dev box instance and its optional firewall.
###############################################################################

resource "linode_instance" "dev_box" {
  label           = local.instance
  image           = local.image
  region          = local.region
  type            = local.instance_type
  tags            = var.tags
  private_ip      = var.private_ip
  backups_enabled = var.backups_enabled

  resize_disk          = false
  migration_type       = "cold"
  interface_generation = "legacy_config"

  metadata {
    user_data = base64encode(local.cloud_init)
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", local.username))
      error_message = "Resolved deploy username '${local.username}' is not a valid Linux username. Set TF_VAR_username or ensure your local $USER is a valid Linux username (lowercase, max 32 chars)."
    }
    precondition {
      condition     = can(regex(local.image_pattern, local.image))
      error_message = "Unsupported image '${local.image}'. Supported: any linode/ubuntu<NN>.<NN> slug (e.g. linode/ubuntu26.04) or private/ image."
    }
    precondition {
      condition     = local.instance_type == "g2-gpu-rtx4000a1-s"
      error_message = "Only g2-gpu-rtx4000a1-s is supported for this baseline."
    }
  }
}

resource "linode_firewall" "dev_box_fw" {
  count = var.create_firewall ? 1 : 0

  label = "${local.instance}-firewall"
  tags  = var.tags

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.allowed_ssh_cidrs_ipv4
    ipv6     = var.allowed_ssh_cidrs_ipv6
  }

  linodes = [linode_instance.dev_box.id]
}

# Explicit disks/config ensure the Ubuntu distribution kernel boots, not a
# provider kernel without matching NVIDIA modules. Fresh deployments only.
resource "linode_instance_disk" "root" {
  linode_id       = linode_instance.dev_box.id
  label           = "ubuntu-root"
  size            = 523264
  filesystem      = "ext4"
  image           = local.image
  root_pass       = var.root_pass
  authorized_keys = var.authorized_keys
}

resource "linode_instance_disk" "swap" {
  linode_id  = linode_instance.dev_box.id
  label      = "swap"
  size       = 1024
  filesystem = "swap"
}

resource "linode_instance_config" "ubuntu" {
  linode_id   = linode_instance.dev_box.id
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
