# ALB
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "load_balancer" {
  count              = var.disable_autoscaling[0] == "true" ? 0 : 1
  name               = var.name[0]
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.include_vpc[0] == "true" ? [aws_security_group.load_balancer[0].id] : [var.include_vpc[7]]
  #subnets                    = var.include_vpc[0] == "true" ? (var.include_frontend_ecs_service == true ? [aws_subnet.subnet_a[0].id, aws_subnet.subnet_b[0].id, aws_subnet.subnet_c[0].id, aws_subnet.subnet_d[0].id] : [aws_subnet.subnet_c[0].id, aws_subnet.subnet_d[0].id]) : (var.include_frontend_ecs_service == true ? [var.include_vpc[2], var.include_vpc[3], var.include_vpc[4], var.include_vpc[5]] : [var.include_vpc[4], var.include_vpc[5]])
  subnets                    = var.include_vpc[0] == "true" ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
  enable_deletion_protection = false
  tags = {
    Project     = "${var.name[0]}"
    Environment = "${var.name[1]}"
  }
}

# Target Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group-
# Backend
resource "aws_lb_target_group" "blue" {
  count    = var.disable_autoscaling[0] == "true" ? 0 : 1
  name     = "${var.name[0]}-blue"
  port     = 80
  protocol = "HTTP"
  #target_type          = var.fargate_cluster == true ? "ip" : "instance"
  target_type          = "ip"
  vpc_id               = var.include_vpc[0] == "true" ? aws_vpc.vpc[count.index].id : var.include_vpc[1]
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}

resource "aws_lb_target_group" "green" {
  count                = var.disable_autoscaling[0] == "true" ? 0 : 1
  name                 = "${var.name[0]}-green"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.include_vpc[0] == "true" ? aws_vpc.vpc[count.index].id : var.include_vpc[1]
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}


# Frontend
resource "aws_lb_target_group" "frontend_blue" {
  count                = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  name                 = "${var.name[0]}-frontend-blue"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.include_vpc[0] == "true" ? aws_vpc.vpc[count.index].id : var.include_vpc[1]
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}

resource "aws_lb_target_group" "frontend_green" {
  count                = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  name                 = "${var.name[0]}-frontend-green"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.include_vpc[0] == "true" ? aws_vpc.vpc[count.index].id : var.include_vpc[1]
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}

# Listener & Listener rule
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
# Doc: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
resource "aws_lb_listener" "listener" {
  count             = var.disable_autoscaling[0] == "true" ? 0 : 1
  load_balancer_arn = aws_lb.load_balancer[count.index].arn
  port              = var.force_HTTPS[0] == "true" ? "443" : "80" # HTTP 80 used, for HTTPS 443 port there must be a TLS certificate defined.
  protocol          = var.force_HTTPS[0] == "true" ? "HTTPS" : "HTTP"
  ssl_policy        = var.force_HTTPS[0] == "true" ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = var.force_HTTPS[0] == "true" ? "${var.force_HTTPS[1]}" : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue[count.index].arn
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}


# Listener rule: Backend
resource "aws_lb_listener_rule" "backend" {
  count        = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  listener_arn = aws_lb_listener.listener[count.index].arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue[count.index].arn
  }

  condition {
    host_header {
      values = ["backend.${var.domain}"]
    }
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}

# Listener rule: Frontend
resource "aws_lb_listener_rule" "frontend" {
  count        = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  listener_arn = aws_lb_listener.listener[count.index].arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_blue[count.index].arn
  }

  condition {
    host_header {
      values = ["frontend.${var.domain}"]
    }
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}