# =============================================================================
# EFS: disco de red compartido por todos los servidores web.
# Así WordPress (plugins, temas, fotos subidas) es el mismo en todos: si el ALB
# manda al cliente a otro servidor, ve exactamente la misma web.
# Un punto de montaje en cada subred de aplicación (una por zona).
# =============================================================================
resource "aws_efs_file_system" "wp" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  tags = { Name = "${local.name}-wp-efs" }
}

resource "aws_efs_mount_target" "wp" {
  count           = length(local.app_subnets)
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = local.app_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}
