# Doc:Fragate: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-capacity-providers.html
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers
# Doc:EC2: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider
# 1. Capacity Provider
## Fargate: Assign capacity providers to be used with ecs cluster
resource "aws_ecs_cluster_capacity_providers" "provider" {
  count              = var.fargate_cluster == true ? 1 : 0 # Could be removed if EC2 and ECS fargate are required to be created together
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    # FARGATE_SPOT is prioritized with a base of 1 task and a higher weight
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }

  default_capacity_provider_strategy {
    # FARGATE has a base of 0 tasks and a lower weight
    base              = 0
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

# 2. Service
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
# For service autoscaling, we will use aws_appautoscaling_target resource.
resource "aws_ecs_service" "service" {
  count                             = var.fargate_cluster == true ? 1 : 0
  name                              = local.environment_names[count.index]
  cluster                           = aws_ecs_cluster.cluster.id
  force_new_deployment              = true
  task_definition                   = aws_ecs_task_definition.task_def.arn
  desired_count                     = 1
  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }
  deployment_controller {
    type = var.enable_service_connect == false ? "CODE_DEPLOY" : "ECS" # Requires IAM role to access ecs cluster
  }
  network_configuration {
    subnets          = var.include_vpc[0] == "true" ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
    security_groups  = var.include_vpc[0] == "true" ? [aws_security_group.application_sg[count.index].id] : [var.include_vpc[6]]
    assign_public_ip = true
  }

  # Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/register-multiple-targetgroups.html
  load_balancer {
    target_group_arn = var.disable_autoscaling[0] == "false" ? aws_lb_target_group.blue[0].arn : var.disable_autoscaling[3]
    container_name   = var.enable_nginx[0] == true ? "nginx" : "${var.name[0]}"
    container_port   = 80
  }

  # Used for EBS
  dynamic "volume_configuration" {
    for_each = var.include_efs_ebs_bind[1] ? [1] : []
    content {
      name = "${var.name[0]}_volume"
      managed_ebs_volume {
        role_arn   = aws_iam_role.ecs_task_execution_role.arn
        size_in_gb = tonumber(var.storage_details[0])
      }
    }
  }

  # Service connect will ignore the nginx image as it is used as a proxy
  service_connect_configuration {
    enabled   = var.enable_service_connect == true ? true : false
    namespace = aws_service_discovery_http_namespace.namespace.arn
    service {
      discovery_name = var.name[0]
      port_name      = var.name[0]
      client_alias {
        dns_name = var.name[0]
        port     = var.backend_ecs_config[0]
      }
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

# Frontend service
resource "aws_ecs_service" "service_frontend" {
  count                = var.fargate_cluster == true && var.include_frontend_ecs_service == true ? 1 : 0
  name                 = local.frontend_environment_names[count.index]
  cluster              = aws_ecs_cluster.cluster.id
  force_new_deployment = false
  #launch_type     = "FARGATE"
  task_definition                   = aws_ecs_task_definition.frontend_task_def[count.index].arn
  desired_count                     = 1
  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 10
  }

  deployment_controller {
    type = var.enable_service_connect == false ? "CODE_DEPLOY" : "ECS" # Requires IAM role to access ecs cluster
  }

  network_configuration {
    subnets          = var.include_vpc[0] == "true" && var.include_frontend_ecs_service == true ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
    security_groups  = var.include_vpc[0] == "true" ? [aws_security_group.application_sg[count.index].id] : [var.include_vpc[6]]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = var.enable_service_connect == true ? true : false
    namespace = aws_service_discovery_http_namespace.namespace.arn
    service {
      port_name      = "${var.name[0]}-frontend"
      discovery_name = "${var.name[0]}-frontend"
      client_alias {
        dns_name = "${var.name[0]}-frontend"
        port     = var.frontend_ecs_config[0]
      }
    }
  }
  # Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/register-multiple-targetgroups.html

  load_balancer {
    target_group_arn = var.disable_autoscaling[0] == "false" ? aws_lb_target_group.frontend_blue[count.index].arn : var.disable_autoscaling[5]
    container_name   = var.enable_nginx[1] == true ? "nginx" : "${var.name[0]}-frontend"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = all
  }
}

## 4. Service AutoScaling
### We'll use Autoscaling application to control auto scalability of tasks
### Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy
### Doc: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html
resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.fargate_cluster == true ? 1 : 0
  max_capacity       = 1
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service[count.index].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [
      max_capacity,
      min_capacity
    ]
  }
}

resource "aws_appautoscaling_target" "frontend_ecs_target" {
  count              = var.include_frontend_ecs_service == true && var.fargate_cluster == true ? 1 : 0
  max_capacity       = 1
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service_frontend[count.index].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [
      max_capacity,
      min_capacity
    ]
  }
}

#### ECS Metrics Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/available_cloudwatch_metrics.html
#### Target scaling policy
resource "aws_appautoscaling_policy" "backend" {
  count              = var.fargate_cluster == true ? 1 : 0
  name               = var.name[0]
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 90
    scale_in_cooldown  = 120
    scale_out_cooldown = 60

    customized_metric_specification {
      metrics {
        label = "${var.name[0]}-CPUUtilization-metrics"
        id    = "m1"

        metric_stat {
          metric {
            metric_name = "CPUUtilization"
            namespace   = "CPUUtilization"

            dimensions {
              name  = "ClusterName"
              value = aws_ecs_cluster.cluster.name
            }

            dimensions {
              name  = "ServiceName"
              value = local.environment_names[0]
            }
          }

          stat = "Average"
        }

        return_data = true
      }
    }
  }

  lifecycle {
    ignore_changes = [
      target_tracking_scaling_policy_configuration
    ]
  }
}


resource "aws_appautoscaling_policy" "frontend" {
  count              = var.include_frontend_ecs_service == true && var.fargate_cluster == true ? 1 : 0
  name               = var.name[0]
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend_ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.frontend_ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend_ecs_target[count.index].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 90
    scale_in_cooldown  = 120
    scale_out_cooldown = 60

    customized_metric_specification {
      metrics {
        label = "${var.name[0]}-CPUUtilization-metrics"
        id    = "m1"

        metric_stat {
          metric {
            metric_name = "CPUUtilization"
            namespace   = "CPUUtilization"

            dimensions {
              name  = "ClusterName"
              value = aws_ecs_cluster.cluster.name
            }

            dimensions {
              name  = "ServiceName"
              value = local.frontend_environment_names[0]
            }
          }

          stat = "Average"
        }

        return_data = true
      }
    }
  }

  lifecycle {
    ignore_changes = [
      target_tracking_scaling_policy_configuration
    ]
  }
}