# =============================================================================
# INSTANCIA NAT (en lugar de un NAT gateway)
#
# NAT gateway: 0,045 $/h y cobra las 24 h aunque el lab esté parado.
# Instancia NAT: t3.nano (~0,01 $/h con su IP) y el lab la apaga sola.
# Contrapartida: no es redundante. Si se cae, las máquinas privadas no pueden
# descargar nada, pero la web sigue funcionando (los clientes entran por el ALB).
# =============================================================================

# Última AMI de Amazon Linux 2023 publicada por Amazon
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Cortafuegos de la NAT: solo acepta tráfico que venga de dentro de la VPC
resource "aws_security_group" "nat" {
  name        = "${local.name}-nat"
  description = "Instancia NAT: entra solo trafico de la VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Todo lo que venga de la VPC (para reenviarlo a Internet)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Salida a Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-nat" }
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile

  # Imprescindible en una NAT: por defecto EC2 descarta el tráfico que no
  # va dirigido a la propia máquina. Esto le permite reenviar el de otras.
  source_dest_check = false

  user_data = file("${path.module}/templates/nat_user_data.sh")

  metadata_options {
    http_tokens = "required" # IMDSv2 (más seguro)
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${local.name}-nat" }

  # 19 oct: si Amazon publica una AMI nueva de AL2023, NO recrear la NAT en cada apply
  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_route.public_internet]
}
