output "web_url" {
  description = "Abre esto en el navegador (aviso de certificado autofirmado: Avanzado → Continuar)"
  value       = "https://${aws_lb.web.dns_name}"
}

output "demo_balanceo" {
  description = "Recarga varias veces: cambia el servidor que responde"
  value       = "https://${aws_lb.web.dns_name}/servidor.php"
}

output "rds_endpoint" {
  value = aws_db_instance.wp.address
}

output "rds_multi_az" {
  value = aws_db_instance.wp.multi_az
}

output "efs_id" {
  value = aws_efs_file_system.wp.id
}
