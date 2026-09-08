###############################################################################
# Instance basics
###############################################################################

variable "region" {
  description = "Akamai (Linode) region slug. Optional - inherits from ~/.config/linode-cli, then falls back to de-fra-2."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.region == null || can(regex("^[a-z]{2,3}-[a-z]+(-[0-9]+)?$", var.region))
    error_message = "Region must look like a valid Akamai region slug (e.g. de-fra-2)."
  }
}

variable "instance_type" {
  description = "Akamai (Linode) instance plan. Optional - inherits from ~/.config/linode-cli, then falls back to g2-gpu-rtx4000a1-s."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.instance_type == null || can(regex("^g[0-9]+-", var.instance_type))
    error_message = "Instance type must be a valid Linode plan slug."
  }
}

variable "instance_label" {
  description = "Label for the Linode instance and base for derived names (firewall, hostname). Defaults to <username>-ai-dev-box when null."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.instance_label == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$", var.instance_label))
    error_message = "Instance label must start with a letter or digit and contain only letters, digits, hyphens, or underscores (max 64 chars)."
  }
}

variable "image" {
  description = "Akamai image slug. Optional - inherits from ~/.config/linode-cli, then falls back to linode/ubuntu26.04. Supported: any linode/ubuntu<NN>.<NN> slug or private/ image."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.image == null || can(regex("^(linode/ubuntu[0-9]+\\.[0-9]+|private/)", var.image))
    error_message = "Image must be an Ubuntu image slug (e.g. linode/ubuntu26.04) or a private/ image slug."
  }
}

variable "hostname" {
  description = "System hostname. Defaults to the instance label when empty."
  type        = string
  default     = ""

  validation {
    condition     = var.hostname == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.hostname))
    error_message = "Hostname must be a valid DNS label (lowercase letters, digits, hyphens, 1-63 chars, not starting/ending with hyphen)."
  }
}

variable "timezone" {
  description = "IANA timezone for the box (e.g. UTC, Europe/Kyiv)."
  type        = string
  default     = "UTC"

  validation {
    condition     = can(regex("^[A-Za-z]+(/[A-Za-z_+-]+){0,2}$", var.timezone))
    error_message = "Timezone must look like a valid IANA timezone (e.g. UTC, Europe/Kyiv)."
  }
}

variable "tags" {
  description = "Tags to apply to the instance and firewall."
  type        = list(string)
  default     = ["dev", "ai-dev-box", "gpu", "ubuntu"]
}

variable "private_ip" {
  description = "Enable a private IP on the instance."
  type        = bool
  default     = false
}

variable "backups_enabled" {
  description = "Enable Akamai automated backups (additional cost)."
  type        = bool
  default     = false
}

###############################################################################
# User / SSH
###############################################################################

variable "username" {
  description = "Non-root Linux user to create on the box. Defaults to local $USER at apply time (override via TF_VAR_username or $DEVBOX_USER). Must be a valid Linux username."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.username == null || can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.username))
    error_message = "Username must be a valid Linux username (start with lowercase letter or underscore, up to 32 chars)."
  }
}

variable "authorized_keys" {
  description = "List of SSH public keys authorised for the non-root user. Ed25519 recommended."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.authorized_keys : can(regex("^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp(256|384|521)) ", key))])
    error_message = "Each authorized key must be a valid SSH public key (ssh-rsa, ssh-ed25519, ssh-dss, ecdsa-sha2-nistp*)."
  }
}

variable "root_pass" {
  description = "Root password (required by Linode API, but SSH key auth is used). Generate with `openssl rand -base64 32`."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.root_pass) >= 16
    error_message = "Root password must be at least 16 characters long."
  }
}

###############################################################################
# Firewall
###############################################################################

variable "create_firewall" {
  description = "Create and attach a Cloud Firewall."
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs_ipv4" {
  description = "IPv4 CIDRs allowed to access SSH (port 22). Restrict to your own IP for production use."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ssh_cidrs_ipv4 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv4 CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "allowed_ssh_cidrs_ipv6" {
  description = "IPv6 CIDRs allowed to access SSH (port 22)."
  type        = list(string)
  default     = ["::/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ssh_cidrs_ipv6 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv6 CIDR."
  }
}

###############################################################################
# Cloud-init
###############################################################################

variable "extra_packages" {
  description = "Additional apt packages to install on first boot via cloud-init."
  type        = list(string)
  default     = []
}
