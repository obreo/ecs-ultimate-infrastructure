# This is used to defiine green/blue deployment for ecs using codedeploy. ECS service depends on this resource to run under CodeDeploy configuration.
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html

resource "aws_codedeploy_app" "app" {
  count            = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  compute_platform = "ECS"
  name             = var.name[0]
}

resource "aws_codedeploy_deployment_group" "group" {
  count    = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  app_name = aws_codedeploy_app.app[count.index].name
  # Application deployment method to instances - whether gradually or all at once
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = var.name[0]
  service_role_arn       = aws_iam_role.codeDeploy_role[count.index].arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
      # Time to move traffic
      # wait_time_in_minutes = 1
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }
  # Traffic shift from blue to green method
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = var.fargate_cluster == true ? aws_ecs_service.service[count.index].name : aws_ecs_service.service_ec2[count.index].name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.listener[count.index].arn]
      }

      target_group {
        name = aws_lb_target_group.blue[count.index].name
      }

      target_group {
        name = aws_lb_target_group.green[count.index].name
      }
    }
  }
}

/*
resource "aws_codedeploy_app" "frontend_app" {
  count            = var.include_frontend_ecs_service == true && var.disable_autoscaling[0] == "false" ? 1 : 0
  compute_platform = "ECS"
  name             = "${var.name[0]}-frontend"
}
*/

resource "aws_codedeploy_deployment_group" "frontend_group" {
  count    = var.enable_service_connect == false && var.include_frontend_ecs_service == true && var.disable_autoscaling[0] == "false" ? 1 : 0
  app_name = aws_codedeploy_app.app[count.index].name
  # Application deployment method to instances - whether gradually or all at once
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${var.name[0]}-frontend"
  service_role_arn       = aws_iam_role.codeDeploy_role[count.index].arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
      # Time to move traffic
      #wait_time_in_minutes = 1
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }
  # Traffic shift from blue to green method
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = var.fargate_cluster == true ? aws_ecs_service.service_frontend[count.index].name : aws_ecs_service.service_ec2_frontend[count.index].name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.listener[count.index].arn]
      }

      target_group {
        name = aws_lb_target_group.frontend_blue[count.index].name
      }

      target_group {
        name = aws_lb_target_group.frontend_green[count.index].name
      }
    }
  }
}
######################################################
# CodeDeploy-ECS Execution Role
######################################################
resource "aws_iam_role" "codeDeploy_role" {
  count              = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  name               = "CodeDeploy_ECS_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.codeDeploy_role[count.index].json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "codeDeploy_role" {
  count = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
#Policy Attachment
resource "aws_iam_policy_attachment" "codeDeploy_role" {
  count      = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  name       = "ecs_task_execution_role"
  roles      = ["${aws_iam_role.codeDeploy_role[count.index].name}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_policy_attachment" "codeDeploy_role_2" {
  count      = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  name       = "Custome_Policy_to_access_S3"
  roles      = ["${aws_iam_role.codeDeploy_role[count.index].name}"]
  policy_arn = aws_iam_policy.codedeploy-custom-policy[count.index].arn
}
#####################################################
# End of Role
#####################################################

# Custome Policy to access S3:
resource "aws_iam_policy" "codedeploy-custom-policy" {
  count       = var.enable_service_connect == true || var.disable_autoscaling[0] == "true" ? 0 : 1
  name        = "codedeploy-custom-policy"
  path        = "/"
  description = "Custome Policy to access S3"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/*",
          "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}"
        ]
      },
      {
        Sid    = "Artifacts"
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::codepipeline-${var.region}-*"
        ]
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      }
    ]
  })

}
