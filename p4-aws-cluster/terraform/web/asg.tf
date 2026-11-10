# =============================================================================
# SERVIDORES WEB: plantilla de lanzamiento + Auto Scaling Group
#  - 2 servidores como mínimo, uno en cada zona (subredes app, sin IP pública)
#  - Si uno falla la comprobación del ALB, el ASG lo sustituye solo
#  - Si la CPU media pasa del 60 %, añade servidores (hasta web_max)
# =============================================================================
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name}-web-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.web_instance_type

  iam_instance_profile {
    name = var.instance_profile
  }

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/templates/wordpress_user_data.sh.tftpl", {
    efs_id    = aws_efs_file_system.wp.id
    region    = var.region
    ssm_param = aws_ssm_parameter.db_password.name
    db_host   = aws_db_instance.wp.address
    db_name   = var.db_name
    db_user   = var.db_user
  }))

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-web" }
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${local.name}-web-asg"
  vpc_zone_identifier       = local.app_subnets
  min_size                  = var.web_min
  desired_capacity          = var.web_min
  max_size                  = var.web_max
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-web"
    propagate_at_launch = true
  }

  depends_on = [aws_efs_mount_target.wp, aws_db_instance.wp]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-web-cpu60"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
