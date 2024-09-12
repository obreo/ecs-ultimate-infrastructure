# Global Settings for ECS Cluster - Both Fargate and EC2
# https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-deployment

# 1. Namespace
resource "aws_service_discovery_http_namespace" "namespace" {
  name        = var.name[0]
  description = "app"
}

# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster
# 2. Cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.name[0]
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.namespace.arn
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.log.name
      }
    }
  }
}

# 2.1 Logs to Cloudwatch
resource "aws_cloudwatch_log_group" "log" {
  name = "/ecs/${var.name[0]}/cluster"
}


# 3.Task_Definition
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html
resource "aws_ecs_task_definition" "task_def" {
  family                   = var.name[0]
  cpu                      = var.backend_ecs_config[1]
  memory                   = var.backend_ecs_config[2]
  network_mode             = "awsvpc"
  requires_compatibilities = var.include_efs_ebs_bind[1] == "fasle" ? ["FARGATE", "EC2"] : ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions    = <<TASK_DEFINITION
  ${var.include_external_taskdefinition_file[0] ? (local.custom_backend_task_def) : (var.enable_nginx[0] ? local.backend_task_def : local.backend_task_def_non_nginx)}
  TASK_DEFINITION

  runtime_platform {
    cpu_architecture = var.enable_arm64 ? "ARM64" : "X86_64"
  }
  lifecycle {
    ignore_changes = all
  }
}

# Frontend Task definition
resource "aws_ecs_task_definition" "frontend_task_def" {
  count                    = var.include_frontend_ecs_service == true ? 1 : 0
  family                   = local.frontend_environment_names[0]
  cpu                      = var.frontend_ecs_config[1]
  memory                   = var.frontend_ecs_config[2]
  network_mode             = "awsvpc"
  requires_compatibilities = var.include_efs_ebs_bind[1] == "true" ? ["FARGATE"] : ["FARGATE", "EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions    = <<TASK_DEFINITION
  ${var.include_external_taskdefinition_file[1] ? (local.custom_frontend_task_def) : (var.enable_nginx[1] ? local.frontend_task_def : local.frontend_task_def_non_nginx)}
  TASK_DEFINITION

  runtime_platform {
    cpu_architecture = var.enable_arm64 ? "ARM64" : "X86_64"
  }

  lifecycle {
    ignore_changes = all
  }
}
