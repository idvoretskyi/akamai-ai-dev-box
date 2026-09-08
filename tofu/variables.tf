variable "region" {
  description = "Region with RTX 4000 Ada Small availability. Check availability before deployment."
  type        = string
  default     = "de-fra-2"
}

variable "label" {
  description = "Instance label and hostname. Use a distinct name for each deployment."
  type        = string
  default     = "ai-dev-box"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.label))
    error_message = "Use a lowercase hostname of 2-63 characters, without a trailing hyphen."
  }
}

variable "username" {
  description = "Single-user development account. SSH keys only; passwordless sudo for administration."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,30}$", var.username)) && !contains(["root", "ollama", "ubuntu", "nobody", "daemon", "bin", "sys", "sync", "games", "man", "lp", "mail", "news", "uucp", "proxy", "www-data", "backup", "list", "irc", "_apt", "systemd-network", "systemd-resolve", "messagebus", "sshd"], var.username)
    error_message = "Use a non-system Linux username (1-31 lowercase characters)."
  }
}

variable "ssh_public_keys" {
  description = "SSH public keys for the developer. No private keys."
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0 && alltrue([for key in var.ssh_public_keys : can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+( .*)?$", key))])
    error_message = "Supply at least one SSH public key."
  }
}

variable "ssh_allowed_ipv4" {
  description = "IPv4 source CIDRs allowed to SSH; required to avoid an open-to-world default."
  type        = list(string)

  validation {
    condition     = length(var.ssh_allowed_ipv4) > 0 && alltrue([for cidr in var.ssh_allowed_ipv4 : can(cidrnetmask(cidr)) && !can(regex("/0$", cidr))])
    error_message = "Supply valid IPv4 CIDRs narrower than /0, normally your public address/32."
  }
}

variable "ssh_allowed_ipv6" {
  description = "Optional IPv6 source CIDRs allowed to SSH."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_ipv6 : can(cidrhost(cidr, 0)) && strcontains(cidr, ":") && !can(regex("/0$", cidr))])
    error_message = "Supply valid IPv6 CIDRs narrower than /0, normally your public address/128."
  }
}

variable "root_password" {
  description = "Initial root console password; SSH password/root login are disabled. Sensitive state still needs protection."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.root_password) >= 20
    error_message = "Use a unique generated root password of at least 20 characters."
  }
}
