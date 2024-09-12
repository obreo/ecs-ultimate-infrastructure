# Reference doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_Types.html
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
resource "aws_codebuild_project" "nginx" {
  count         = var.build_nginx_application[0] == "true" ? 1 : 0
  name          = "nginx"
  description   = "${var.name[0]}- nginx proxy sesrver"
  build_timeout = 10 #min
  service_role  = aws_iam_role.codebuild-role.arn

  # Doc: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-codebuild-project-artifacts.html
  # Artifacts will be used to push the taskdefinition.json, appspec.yml that will be modified with the image tag. This will be used by codedeploy to update the ECS service.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
    compute_type = "BUILD_GENERAL1_SMALL"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html#environment.types
    # For Lmbda computes: Only available for environment type LINUX_LAMBDA_CONTAINER and ARM_LAMBDA_CONTAINER
    type = "LINUX_CONTAINER"
    # When you use a cross-account or private registry image, you must use SERVICE_ROLE credentials. When you use an AWS CodeBuild curated image, you must use CODEBUILD credentials.
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-${var.name[0]}-nginx"
      stream_name = "codebuild-log-stream"
    }
  }
  source {
    type = "NO_SOURCE"
    # The following buildspec scripts are conditional, if the write_nginx_config variable is enabled, then codebuild will write the nginx config, dockerfile, then build the docker image and push it to ECR during deployment using local-exec terraform feature.
    # if write_nginx_config variable is disabled, the second buildspec will be used by codebuild which will use the nginx config file uploaded in the code repository and build the dockerfile and push it to ECR manually after specifying the branch variable for the codebuild hook and code connect arn for the repository.
    buildspec = var.write_nginx_config == true ? local.buildspec_not_version_controlled : local.buildspec_version_controlled
  }
}

resource "null_resource" "trigger_nginx" {
  count = var.build_nginx_application[0] == "true" && var.write_nginx_config == true && var.trigger_nginx[0] ? 1 : 0
  provisioner "local-exec" {
    environment = {
      AWS_PROFILE                 = ""
      AWS_CONFIG_FILE             = "${path.module}/.aws/config"
      AWS_SHARED_CREDENTIALS_FILE = "${path.module}/.aws/credentials"
    }
    command = <<EOT
      aws codebuild start-build --region ${var.region} --project-name nginx
    EOT
  }

  depends_on = [aws_codebuild_project.nginx]
}



# Frontend
resource "aws_codebuild_project" "frontend_nginx" {
  count         = var.build_nginx_application[0] == "true" && var.include_frontend_ecs_service == true ? 1 : 0
  name          = "frontend-nginx"
  description   = "${var.name[0]}- nginx proxy server"
  build_timeout = 10 #min
  service_role  = aws_iam_role.codebuild-role.arn

  # Doc: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-codebuild-project-artifacts.html
  # Artifacts will be used to push the taskdefinition.json, appspec.yml that will be modified with the image tag. This will be used by codedeploy to update the ECS service.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
    compute_type = "BUILD_GENERAL1_SMALL"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html#environment.types
    # For Lmbda computes: Only available for environment type LINUX_LAMBDA_CONTAINER and ARM_LAMBDA_CONTAINER
    type = "LINUX_CONTAINER"
    # When you use a cross-account or private registry image, you must use SERVICE_ROLE credentials. When you use an AWS CodeBuild curated image, you must use CODEBUILD credentials.
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-${var.name[0]}-nginx-frontend"
      stream_name = "codebuild-log-stream"
    }
  }
  source {
    type = "NO_SOURCE"
    # The following buildspec scripts are conditional, if the write_nginx_config variable is enabled, then codebuild will write the nginx config, dockerfile, then build the docker image and push it to ECR during deployment using local-exec terraform feature.
    # if write_nginx_config variable is disabled, the second buildspec will be used by codebuild which will use the nginx config file uploaded in the code repository and build the dockerfile and push it to ECR manually after specifying the branch variable for the codebuild hook and code connect arn for the repository.
    buildspec = var.write_nginx_config == true ? local.frontend_buildspec_not_version_controlled : local.frontend_buildspec_version_controlled
  }
}

resource "null_resource" "trigger_frontend_nginx" {
  count = var.build_nginx_application[0] == "true" && var.write_nginx_config == true && var.trigger_nginx[1] == true ? 1 : 0
  provisioner "local-exec" {
    environment = {
      AWS_PROFILE                 = " "
      AWS_CONFIG_FILE             = "${path.module}/.aws/config"
      AWS_SHARED_CREDENTIALS_FILE = "${path.module}/.aws/credentials"
    }
    command = <<EOT
      aws codebuild start-build --region ${var.region} --project-name frontend-nginx
    EOT
  }

  depends_on = [aws_codebuild_project.frontend_nginx]
}

