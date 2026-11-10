# =============================================================================
# BALANCEADOR (Application Load Balancer) en las 2 subredes públicas
#  - 80  → redirige a 443
#  - 443 → reparte entre los servidores web sanos (comprobación de salud cada 15 s)
# Si un servidor deja de responder, el ALB deja de mandarle clientes.
# =============================================================================
resource "aws_lb" "web" {
  name               = "${local.name}-web-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnets

  drop_invalid_header_fields = true
  tags                       = { Name = "${local.name}-web-alb" }
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/salud.html"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  # El panel de administración de WordPress funciona mejor si el cliente
  # vuelve al mismo servidor durante un rato
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600
    enabled         = true
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.web.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
