terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
