# =============================================================================
# CORTAFUEGOS EN CADENA: Internet → ALB → servidores web → RDS / EFS
# Cada capa solo acepta tráfico de la anterior.
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB: HTTP y HTTPS desde Internet"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP (se redirige a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb" }
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Servidores web: solo HTTP desde el ALB"
  vpc_id      = local.vpc_id

  ingress {
    description     = "HTTP desde el balanceador"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida (paquetes, WordPress, SSM) por la NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-web" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "RDS MySQL: solo desde los servidores web"
  vpc_id      = local.vpc_id

  ingress {
    description     = "MySQL desde los servidores web"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = { Name = "${local.name}-db" }
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "EFS: solo NFS desde los servidores web"
  vpc_id      = local.vpc_id

  ingress {
    description     = "NFS desde los servidores web"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = { Name = "${local.name}-efs" }
}
