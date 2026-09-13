###############################################################################
# Resolved values: variable -> linode-cli config -> hardcoded fallback.
# The deploy username is derived from local $USER at plan/apply time.
###############################################################################

locals {
  cli = data.external.linode_cli.result

  region        = coalesce(var.region, try(local.cli.region, ""), "de-fra-2")
  instance_type = coalesce(var.instance_type, try(local.cli.type, ""), "g2-gpu-rtx4000a1-s")
  image         = coalesce(var.image, try(local.cli.image, ""), "linode/ubuntu26.04")

  image_pattern = "^linode/ubuntu26\\.04$"

  # Shared with tofu/main.tf preconditions. Variable-level `validation` blocks
  # cannot reference locals (Terraform restricts them to the variable itself),
  # so the same patterns are also inlined in tofu/variables.tf.
  dns_label_regex = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
  username_regex  = "^[a-z_][a-z0-9_-]{0,31}$"

  username = coalesce(var.username, data.external.local_user.result.username)
  instance = coalesce(var.instance_label, "${local.username}-ai-dev-box")
  hostname = var.hostname == "" ? local.instance : var.hostname

  bootstrap_script = file("${path.module}/cloud-init/bootstrap.sh")
  service_unit     = file("${path.module}/cloud-init/ai-dev-box-bootstrap.service")
  ollama_unit      = file("${path.module}/cloud-init/ollama.service")

  releases = jsondecode(file("${path.module}/cloud-init/releases.json"))

  cloud_init = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username         = local.username
    hostname         = local.hostname
    timezone         = var.timezone
    ssh_keys         = var.authorized_keys
    extra_packages   = var.extra_packages
    ollama_version   = local.releases.ollama.version
    ollama_sha256    = local.releases.ollama.sha256
    opencode_version = local.releases.opencode.version
    opencode_sha256  = local.releases.opencode.sha256
    bootstrap_script = local.bootstrap_script
    service_unit     = local.service_unit
    ollama_unit      = local.ollama_unit
  })

  ipv4    = try(linode_instance.dev_box.ip_address, "")
  have_ip = local.ipv4 != ""

  # Shared SSH options for the non-interactive operational-helper outputs.
  ssh_batch_opts = "-o BatchMode=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o StrictHostKeyChecking=accept-new"

  # Shared sed expression that deletes a previously installed managed block
  # from ~/.ssh/config; used by both install and remove helper outputs.
  ssh_config_marker_sed = "sed -i.bak '/^# BEGIN akamai-ai-dev-box$/,/^# END akamai-ai-dev-box$/d' ~/.ssh/config 2>/dev/null"

  ssh_config_lines = [
    "# BEGIN akamai-ai-dev-box",
    "Host $USER-ai-dev-box",
    "  HostName ${local.ipv4}",
    "  User ${local.username}",
    "  IdentityFile ~/.ssh/id_ed25519",
    "  StrictHostKeyChecking accept-new",
    "# END akamai-ai-dev-box",
  ]
  ssh_config_block = join("\n", local.ssh_config_lines)
}
