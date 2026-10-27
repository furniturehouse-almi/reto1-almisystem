# Versión de Terraform y del "driver" de AWS que usa este proyecto
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

# Learner Lab: región us-east-1. Las credenciales salen de
# C:\Users\<tu usuario>\.aws\credentials (las copias cada día del panel del lab).
provider "aws" {
  region = var.region

  # Estas etiquetas se ponen solas en todo lo que se cree
  default_tags {
    tags = {
      Project   = "AlmiSystem-Reto1"
      Owner     = "P4-Adrian"
      ManagedBy = "Terraform"
    }
  }
}
