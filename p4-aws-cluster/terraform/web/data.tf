# Red creada en ..\base (VPC, subredes, NAT)
data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "${path.module}/../base/terraform.tfstate"
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  name           = var.project
  vpc_id         = data.terraform_remote_state.base.outputs.vpc_id
  public_subnets = data.terraform_remote_state.base.outputs.public_subnets
  app_subnets    = data.terraform_remote_state.base.outputs.app_subnets
  data_subnets   = data.terraform_remote_state.base.outputs.data_subnets
}
