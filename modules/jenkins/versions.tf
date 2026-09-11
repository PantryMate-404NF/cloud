terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "..."
    }

    helm = {
      source  = "hashicorp/helm"
      version = "..."
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "..."
    }
  }
}