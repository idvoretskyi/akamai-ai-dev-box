terraform {
  backend "s3" {}

  required_version = ">= 1.10"

  required_providers {
    linode = {
      source  = "registry.opentofu.org/linode/linode"
      version = "= 3.12.0"
    }
    external = {
      source  = "registry.opentofu.org/hashicorp/external"
      version = "~> 2.3"
    }
  }
}
