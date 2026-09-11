###############################################################################
# Instance identity
###############################################################################

output "instance_id" {
  description = "Linode instance ID."
  value       = linode_instance.dev_box.id
}

output "instance_label" {
  description = "Linode instance label."
  value       = linode_instance.dev_box.label
}

output "instance_status" {
  description = "Linode instance status."
  value       = linode_instance.dev_box.status
}

output "instance_type" {
  description = "Resolved instance plan."
  value       = linode_instance.dev_box.type
}

output "region" {
  description = "Resolved deployment region."
  value       = linode_instance.dev_box.region
}

output "image" {
  description = "Resolved image slug."
  value       = local.image
}

###############################################################################
# Network
###############################################################################

output "ipv4_address" {
  description = "Public IPv4 address."
  value       = local.have_ip ? local.ipv4 : null
}

output "ipv6_address" {
  description = "IPv6 address."
  value       = linode_instance.dev_box.ipv6
}

output "private_ip_address" {
  description = "Private IPv4 address (if enabled)."
  value       = linode_instance.dev_box.private_ip_address
}

###############################################################################
# Firewall
###############################################################################

output "firewall_id" {
  description = "Firewall ID (null when create_firewall is false)."
  value       = var.create_firewall ? linode_firewall.dev_box_fw[0].id : null
}

output "firewall_status" {
  description = "Firewall status (null when create_firewall is false)."
  value       = var.create_firewall ? linode_firewall.dev_box_fw[0].status : null
}

###############################################################################
# Operational helpers (eval the -raw output to run them)
###############################################################################

output "ssh_command" {
  description = "SSH as the non-root user."
  value       = local.have_ip ? "ssh ${local.username}@${local.ipv4}" : null
}

output "ssh_command_user" {
  description = "SSH as the non-root user."
  value       = local.have_ip ? "ssh ${local.username}@${local.ipv4}" : null
}

output "first_boot_log_command" {
  description = "Tail bootstrap log on the box."
  value       = local.have_ip ? "ssh ${local.username}@${local.ipv4} 'sudo journalctl -u ai-dev-box-bootstrap.service -f'" : null
}

output "wait_ready_command" {
  description = "Poll until staged bootstrap finishes (or fails). Exits 0 on success, 1 on failure."
  value       = local.have_ip ? "for _ in $(seq 1 240); do if ssh -o BatchMode=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o StrictHostKeyChecking=accept-new ${local.username}@${local.ipv4} 'sudo -n test -f /var/lib/ai-dev-box/ready'; then echo ready; exit 0; fi; if ssh -o BatchMode=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o StrictHostKeyChecking=accept-new ${local.username}@${local.ipv4} 'sudo -n systemctl is-failed --quiet ai-dev-box-bootstrap.service'; then echo FAILED - bootstrap service is failed; exit 1; fi; echo waiting...; sleep 15; done; echo FAILED - timeout waiting for /var/lib/ai-dev-box/ready; exit 1" : null
}

###############################################################################
# SSH config helpers
###############################################################################

output "ssh_config_snippet" {
  description = "~/.ssh/config block for this box. Append via ssh_config_install_command."
  value       = local.have_ip ? local.ssh_config_block : null
}

output "ssh_config_install_command" {
  description = "Idempotently install the SSH config block into ~/.ssh/config (removes any previous block first)."
  value       = local.have_ip ? "sed -i.bak '/^# BEGIN akamai-ai-dev-box$/,/^# END akamai-ai-dev-box$/d' ~/.ssh/config 2>/dev/null; rm -f ~/.ssh/config.bak; printf '${replace(join("\\n", local.ssh_config_lines), "$USER", "%s")}\\n' \"$USER\" >> ~/.ssh/config; chmod 600 ~/.ssh/config" : null
}

output "ssh_config_remove_command" {
  description = "Remove the managed SSH config block on destroy."
  value       = "sed -i.bak '/^# BEGIN akamai-ai-dev-box$/,/^# END akamai-ai-dev-box$/d' ~/.ssh/config 2>/dev/null && rm -f ~/.ssh/config.bak && chmod 600 ~/.ssh/config"
}
