terraform {
  required_version = ">= 1.9"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "= 3.12.0"
    }
  }
}

# Use LINODE_TOKEN on the administration host, never in cloud-init or Git.
provider "linode" {}
