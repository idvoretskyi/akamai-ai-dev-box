###############################################################################
# Source defaults from local linode-cli config / OS user when unset.
# Precedence: terraform.tfvars / -var -> ~/.config/linode-cli -> fallback.
###############################################################################

data "external" "linode_cli" {
  program = ["bash", "${path.module}/scripts/read-linode-cli.sh"]
}

data "external" "local_user" {
  program = ["bash", "${path.module}/scripts/read-local-user.sh"]
}
