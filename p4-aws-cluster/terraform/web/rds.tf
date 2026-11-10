# =============================================================================
# BASE DE DATOS MySQL EN ALTA DISPONIBILIDAD (RDS Multi-AZ)
# Multi-AZ = AWS mantiene una réplica síncrona en otra zona y, si cae la
# principal, cambia el DNS del endpoint a la réplica (1-2 min) sin tocar nada.
# La contraseña la genera Terraform y se guarda cifrada en Parameter Store:
# no aparece en el código ni en el repositorio.
# =============================================================================
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "-_.+"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${local.name}/wordpress/db_password"
  description = "Contrasena del usuario de MySQL de WordPress"
  type        = "SecureString"
  value       = random_password.db.result
}

resource "aws_db_subnet_group" "wp" {
  name       = "${local.name}-wp-db"
  subnet_ids = local.data_subnets
  tags       = { Name = "${local.name}-wp-db" }
}

resource "aws_db_instance" "wp" {
  identifier     = "${local.name}-wordpress"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_user
  password = random_password.db.result

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.wp.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true # laboratorio: se destruye cada día
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "${local.name}-wordpress-db" }
}
