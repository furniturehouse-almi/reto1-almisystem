# =============================================================================
# WEB BALANCEADA (paso 3): WordPress en Auto Scaling detrás de un ALB con HTTPS,
# ficheros compartidos en EFS y MySQL en RDS Multi-AZ.
#
# Esta carpeta se CREA y se DESTRUYE en cada sesión del lab (ahorro):
#   1) cd ..\base ; terraform apply      (red + NAT, si no está)
#   2) cd ..\web  ; terraform apply
#   3) al acabar:   terraform destroy   (aquí)  y luego en base si no se va a usar
# Lee la red de ..\base a través de su estado (terraform_remote_state).
# =============================================================================
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.70" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "AlmiSystem-Reto1"
      Owner     = "P4-Adrian"
      ManagedBy = "Terraform"
      Layer     = "web"
    }
  }
}
