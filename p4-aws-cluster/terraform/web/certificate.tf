# =============================================================================
# CERTIFICADO HTTPS
# En el lab no hay dominio público verificable, así que se genera un
# certificado autofirmado y se importa en ACM para el ALB. El navegador avisa
# de que no es de confianza, pero el tráfico va cifrado (TLS).
# En producción: certificado de ACM validado por DNS (gratis y se renueva solo).
# =============================================================================
resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "web" {
  private_key_pem = tls_private_key.web.private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "The Furniture in Your House"
  }

  dns_names             = [var.domain_name]
  validity_period_hours = 24 * 90
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "web" {
  private_key      = tls_private_key.web.private_key_pem
  certificate_body = tls_self_signed_cert.web.cert_pem

  tags = { Name = "${local.name}-web-autofirmado" }
}
