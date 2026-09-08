output "instance_id" {
  value = linode_instance.workstation.id
}

output "ipv4" {
  value = one(linode_instance.workstation.ipv4)
}

output "ssh_command" {
  description = "SSH availability is not GPU readiness; bootstrap performs two reboots."
  value       = "ssh ${var.username}@${one(linode_instance.workstation.ipv4)}"
}
