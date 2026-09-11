###############################################################################
# Core resources: the AI dev box instance and its optional firewall.
###############################################################################

resource "linode_instance" "dev_box" {
  label           = local.instance
  region          = local.region
  type            = local.instance_type
  firewall_id     = var.create_firewall ? linode_firewall.dev_box_fw[0].id : null
  tags            = var.tags
  private_ip      = var.private_ip
  backups_enabled = var.backups_enabled

  migration_type       = "cold"
  interface_generation = "legacy_config"

  metadata {
    user_data = base64encode(local.cloud_init)
  }

  lifecycle {
    precondition {
      condition     = can(regex(local.username_regex, local.username))
      error_message = "Resolved deploy username '${local.username}' is not a valid Linux username. Set TF_VAR_username or ensure your local $USER is a valid Linux username (lowercase, max 32 chars)."
    }
    precondition {
      condition     = !contains(["root", "ollama"], local.username)
      error_message = "Resolved deploy username cannot be root or ollama."
    }
    precondition {
      condition     = can(regex(local.image_pattern, local.image))
      error_message = "Unsupported image '${local.image}'. Supported: linode/ubuntu26.04 for this baseline."
    }
    precondition {
      condition     = local.instance_type == "g2-gpu-rtx4000a1-s"
      error_message = "Only g2-gpu-rtx4000a1-s is supported for this baseline."
    }
    precondition {
      condition     = can(regex(local.dns_label_regex, local.hostname))
      error_message = "Resolved hostname '${local.hostname}' is not a valid lowercase DNS label (1-63 chars)."
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

}

# Explicit disks/config ensure the Ubuntu distribution kernel boots, not a
# provider kernel without matching NVIDIA modules. Fresh deployments only.
# Root disk size (MiB) = plan disk (512 GiB / 524288 MiB) minus the 1024 MiB
# swap disk below, so the two disks exactly fill the g2-gpu-rtx4000a1-s plan.
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
