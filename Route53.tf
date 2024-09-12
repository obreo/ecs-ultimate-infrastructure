# This is used to set Alias DNS records to the elastic load balancer.
# Backend
resource "aws_route53_record" "backend" {
  count   = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  zone_id = var.zone_id
  name    = "backend.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer[count.index].dns_name
    zone_id                = aws_lb.load_balancer[count.index].zone_id
    evaluate_target_health = false
  }
}

# Frontend
resource "aws_route53_record" "frontend" {
  count   = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer[count.index].dns_name
    zone_id                = aws_lb.load_balancer[count.index].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "frontend2" {
  count   = var.disable_autoscaling[0] == "false" && var.include_frontend_ecs_service == true ? 1 : 0
  zone_id = var.zone_id
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer[count.index].dns_name
    zone_id                = aws_lb.load_balancer[count.index].zone_id
    evaluate_target_health = false
  }
}