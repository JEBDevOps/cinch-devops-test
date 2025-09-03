terraform {
  required_version = ">= 0.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.2.0"
    }
    wireguard = {
      source  = "OJFord/wireguard"
      version = "0.3.0"
    }
  }
}
