# ECS EC2 Custer Configuration
# Doc: https://medium.com/@vladkens/aws-ecs-cluster-on-ec2-with-terraform-2023-fdb9f6b7db07
# scale in alaram evalution modification:
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-config.html
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/bootstrap_container_instance.html
# Doc: https://aws.amazon.com/blogs/containers/faster-scaling-in-for-amazon-ecs-cluster-auto-scaling/
# Doc: https://aws.amazon.com/blogs/containers/deep-dive-on-amazon-ecs-cluster-auto-scaling/
#########################################################################################################
# Luanch Template & Autoscaling Group Preperation
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
#########################################################################################################
# --- ECS Launch Template ---
# Retreiving AWS AMI image from AWS owned parameters
data "aws_ssm_parameter" "ecs_ami" {
  name = var.enable_arm64 ? "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id" : "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "ecs_ec2" {
  count                  = var.fargate_cluster == false ? 1 : 0
  name_prefix            = "${var.name[0]}-ecs-ec2"
  image_id               = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.ecs_ec2_type
  vpc_security_group_ids = var.include_vpc[0] == "true" ? [aws_security_group.application_sg[count.index].id] : [var.include_vpc[6]]
  key_name               = var.include_ssh_key[0] == "true" ? aws_key_pair.deployer[count.index].key_name : var.include_vpc[9]
  iam_instance_profile { arn = aws_iam_instance_profile.ecs_ec2_instance[count.index].arn }
  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config;
    EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  count                     = var.fargate_cluster == false ? 1 : 0
  name                      = "${var.name[0]}-ecs-ec2"
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 6
  health_check_grace_period = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.include_vpc[0] == "true" ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
  protect_from_scale_in     = false
  force_delete              = true

  launch_template {
    id      = aws_launch_template.ecs_ec2[count.index].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.name[0]
    propagate_at_launch = true
  }
  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
  tag {
    key                 = "Cluster"
    value               = "ECS EC2"
    propagate_at_launch = true
  }
}

#########################################################################################################
# Luanch Template & Autoscaling Group END
#########################################################################################################

# 1. Capacity Provider: define Autoscaling group as a capacity provider
# Doc:EC2: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider
resource "aws_ecs_capacity_provider" "ec2" {
  count = var.fargate_cluster == false ? 1 : 0
  name  = var.name[0]

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs[count.index].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

# 2. Specify the capacity providers to be used in ecs cluster
resource "aws_ecs_cluster_capacity_providers" "ec2" {
  count              = var.fargate_cluster == false ? 1 : 0
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ec2[count.index].name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[count.index].name
    base              = 1 # Minimum tasks to be launched on this instance
    weight            = 1 # Ratio / Priotity to use this launch over other launches (if any)
  }
}

# 3. Service
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
# For service autoscaling, we will use aws_appautoscaling_target resource.
resource "aws_ecs_service" "service_ec2" {
  count                             = var.fargate_cluster == true ? 0 : 1
  name                              = local.environment_names[count.index]
  cluster                           = aws_ecs_cluster.cluster.id
  force_new_deployment              = true
  task_definition                   = aws_ecs_task_definition.task_def.arn
  force_delete                      = true
  desired_count                     = 1
  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[count.index].name
    base              = 1
    weight            = 1
  }

  deployment_controller {
    type = var.enable_service_connect == false ? "CODE_DEPLOY" : "ECS" # Requires IAM role to access ecs cluster
  }

  network_configuration {
    subnets          = var.include_vpc[0] == "true" ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
    security_groups  = var.include_vpc[0] == "true" ? [aws_security_group.application_sg[count.index].id] : [var.include_vpc[6]]
    assign_public_ip = false
  }

  # Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/register-multiple-targetgroups.html

  load_balancer {
    target_group_arn = var.disable_autoscaling[0] == "false" ? aws_lb_target_group.blue[0].arn : "${var.disable_autoscaling[3]}"
    container_name   = var.enable_nginx[0] == true ? "nginx" : "${var.name[0]}"
    container_port   = var.enable_nginx[0] == true ? 80 : var.backend_ecs_config[0]
  }

  # Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/strategy-examples.html#even-instance
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
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
  # Used for EBS
  dynamic "volume_configuration" {
    for_each = var.include_efs_ebs_bind[1] ? [1] : []
    content {
      name = "${name[0]}_volume"
      managed_ebs_volume {
        role_arn   = aws_iam_role.ecs_task_execution_role.arn
        size_in_gb = tonumber(var.storage_details[0])
      }
    }
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }
}

# Frontend service
resource "aws_ecs_service" "service_ec2_frontend" {
  count                = var.fargate_cluster == false && var.include_frontend_ecs_service == true ? 1 : 0
  name                 = local.frontend_environment_names[count.index]
  cluster              = aws_ecs_cluster.cluster.id
  force_new_deployment = true
  force_delete         = true
  #launch_type     = "FARGATE"
  task_definition                   = aws_ecs_task_definition.frontend_task_def[count.index].arn
  desired_count                     = 1
  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[count.index].name
    base              = 1
    weight            = 1
  }

  deployment_controller {
    type = var.enable_service_connect == false ? "CODE_DEPLOY" : "ECS" # Requires IAM role to access ecs cluster
  }

  network_configuration {
    subnets          = var.include_vpc[0] == "true" && var.include_frontend_ecs_service == true ? [aws_subnet.subnet_a[count.index].id, aws_subnet.subnet_b[count.index].id] : [var.include_vpc[2], var.include_vpc[3]]
    security_groups  = var.include_vpc[0] == "true" ? [aws_security_group.application_sg[count.index].id] : [var.include_vpc[6]]
    assign_public_ip = false
  }

  # Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/strategy-examples.html#even-instance
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
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
    container_port   = var.enable_nginx[1] == true ? 80 : var.frontend_ecs_config[0]
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }
}


## 4. Service AutoScaling
### We'll use Autoscaling application to control auto scalability of tasks
### Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy
### Doc: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html
resource "aws_appautoscaling_target" "ecs_ec2_target" {
  count              = var.fargate_cluster == false ? 1 : 0
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service_ec2[count.index].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [
      max_capacity,
      min_capacity
    ]
  }
}

resource "aws_appautoscaling_target" "frontend_ecs_ec2_target" {
  count              = var.include_frontend_ecs_service == true && var.fargate_cluster == false ? 1 : 0
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service_ec2_frontend[count.index].name}"
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
resource "aws_appautoscaling_policy" "ec2_backend" {
  count              = var.fargate_cluster == false ? 1 : 0
  name               = var.name[0]
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_ec2_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_ec2_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_ec2_target[count.index].service_namespace
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


resource "aws_appautoscaling_policy" "ec2_frontend" {
  count              = var.include_frontend_ecs_service == true && var.fargate_cluster == false ? 1 : 0
  name               = var.name[0]
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend_ecs_ec2_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.frontend_ecs_ec2_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend_ecs_ec2_target[count.index].service_namespace
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