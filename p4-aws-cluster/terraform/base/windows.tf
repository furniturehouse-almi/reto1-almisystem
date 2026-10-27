# =============================================================================
# MÁQUINAS WINDOWS DEL CLÚSTER
#
#   Máquina  AZ  Subred        IP principal   IP clúster    IP listener
#   SQL1     a   datos-a       10.40.21.10    10.40.21.11   10.40.21.12
#   SQL2     b   datos-b       10.40.22.10    10.40.22.11   10.40.22.12
#   DC1      c   datos-c       10.40.23.10    -             -
#
# Las IP .11 y .12 se RESERVAN en la tarjeta de red de AWS, pero en Windows
# solo se configura la principal: las otras las activa el clúster.
# DC1 va en una 3ª zona porque es el testigo del quórum.
# =============================================================================

# Última AMI de Windows Server 2022 (inglés, con escritorio) publicada por Amazon
data "aws_ami" "windows2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

locals {
  windows = {
    DC1 = {
      type     = var.dc_instance_type
      subnet   = 2
      ip       = cidrhost(local.data_cidrs[2], 10)
      extra    = []
      features = "AD-Domain-Services,DNS,FS-FileServer"
    }
    SQL1 = {
      type     = var.sql_instance_type
      subnet   = 0
      ip       = cidrhost(local.data_cidrs[0], 10)
      extra    = [cidrhost(local.data_cidrs[0], 11), cidrhost(local.data_cidrs[0], 12)]
      features = "Failover-Clustering"
    }
    SQL2 = {
      type     = var.sql_instance_type
      subnet   = 1
      ip       = cidrhost(local.data_cidrs[1], 10)
      extra    = [cidrhost(local.data_cidrs[1], 11), cidrhost(local.data_cidrs[1], 12)]
      features = "Failover-Clustering"
    }
  }
}

resource "aws_instance" "windows" {
  # 16 oct: el clúster SQL pasa a LOCAL (VirtualBox). Este bloque se queda como
  # ensayo/referencia y solo se crea con: terraform apply -var="windows_lab=true"
  for_each = var.windows_lab ? local.windows : {}

  ami                    = data.aws_ami.windows2022.id
  instance_type          = each.value.type
  subnet_id              = aws_subnet.data[each.value.subnet].id
  private_ip             = each.value.ip
  secondary_private_ips  = each.value.extra
  vpc_security_group_ids = [aws_security_group.windows.id]
  iam_instance_profile   = var.instance_profile
  key_name               = var.key_name

  user_data = templatefile("${path.module}/templates/windows_user_data.ps1.tftpl", {
    hostname = each.key
    features = each.value.features
  })

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_size = 30 # mínimo de Windows; los discos cobran aunque la máquina esté apagada
    volume_type = "gp3"
    encrypted   = true
  }

  # Si sale una AMI nueva de Windows, NO recrear la máquina (perderíamos el dominio y el clúster)
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "${local.name}-${each.key}" }

  # Necesitan la NAT para salir a Internet en el primer arranque
  depends_on = [aws_route.private_nat, aws_route_table_association.data]
}

# Encender / apagar desde Terraform: terraform apply -var="windows_running=false"
resource "aws_ec2_instance_state" "windows" {
  for_each    = aws_instance.windows
  instance_id = each.value.id
  state       = var.windows_running ? "running" : "stopped"
}
