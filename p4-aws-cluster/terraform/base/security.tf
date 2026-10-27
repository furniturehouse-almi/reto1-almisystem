# =============================================================================
# SECURITY GROUPS (cortafuegos de AWS)
# De momento solo el de las máquinas Windows. Los de la web (ALB, servidores,
# RDS, EFS) se añaden en la semana 3.
# =============================================================================
resource "aws_security_group" "windows" {
  name        = "${local.name}-windows"
  description = "DC1, SQL1 y SQL2: libre entre ellas, nada desde Internet"
  vpc_id      = aws_vpc.main.id

  # Entre DC1, SQL1 y SQL2 todo abierto: AD, DNS, Kerberos, SMB, RPC,
  # clúster (3343), endpoint del Availability Group (5022) y SQL (1433)
  ingress {
    description = "Trafico entre las maquinas Windows"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida a Internet (a través de la NAT) para actualizaciones, descargar
  # SQL Server y hablar con Session Manager
  egress {
    description = "Salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NO hay ninguna regla para RDP (3389) desde Internet: se entra por
  # Session Manager (túnel cifrado), que no necesita puertos abiertos.
  tags = { Name = "${local.name}-windows" }
}
