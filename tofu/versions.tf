terraform {
  backend "s3" {}

  required_version = ">= 1.9"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "= 3.12.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}
