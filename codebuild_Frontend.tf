# Reference doc: https://registry.terraform.io/providers/hashicorpcodebuild_name/aws/latest/docs/resources/codebuild_project
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_Types.html
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
resource "aws_codebuild_project" "codebuild_frontend" {
  count         = var.include_codebuild == true && var.include_frontend_ecs_service == true || var.include_codebuild == true && var.include_frontend_bucket == true && var.include_codebuild_for_s3 == true ? 1 : 0
  name          = "${var.name[0]}-frontend"
  description   = "Frontend for ${var.name[0]}-application"
  build_timeout = 10 #min
  service_role  = aws_iam_role.codebuild-role.arn

  # Doc: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-codebuild-project-artifacts.html
  # Artifacts will be used to push the taskdefinition.json, appspec.yml that will be modified with the image tag. This will be used by codedeploy to update the ECS service.
  artifacts {
    type                = "S3"
    packaging           = "NONE"
    path                = "artifacts/${var.name[0]}-frontend"
    namespace_type      = "BUILD_ID"
    name                = "Build_Artifacts"
    encryption_disabled = true
    location            = var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[count.index].id : var.artifacts_bucket[1]
  }

  # You can save time when your project builds by using a cache. A cache can store reusable pieces of your build environment and use them across multiple builds. 
  # Your build project can use one of two types of caching: Amazon S3 or local. 
  /*
  cache {
    type     = "S3"
    location = aws_s3_bucket.elb.bucket
  }
*/
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

    # Environment Variables
    /*
    # 1
    # Key
    environment_variable {
      name  = var.env_name_a
      value = var.env_value_a
    }
    # Value
    environment_variable {
      name  = var.env_name_b
      value = var.env_value_b
    }
    # 2
    # Key
    environment_variable {
      name  = var.env_name_c
      value = var.env_value_c
    }
    # Value
    environment_variable {
      name  = var.env_name_d
      value = var.env_value_d
    }
    */
  }


  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-group"
      stream_name = "codebuild-log-stream"
    }
  }

  # Doc: https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-taskdefinition
  source {
    type = "NO_SOURCE"
    #  buildspec = var.fargate_cluster == true && var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == false ? local.buildspec_frontend_ecs_fargate : var.fargate_cluster == false && var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == false ? local.buildspec_frontend_ecs_ec2 : var.include_frontend_ecs_service == false && var.include_frontend_bucket == true ? local.buildspec_frontend_s3 : var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == true ? local.frontend_service_connect : : null
    buildspec = (
      var.include_frontend_ecs_service ? (
        var.enable_service_connect ? (
          var.enable_nginx[1] ? local.frontend_service_connect : local.frontend_service_connect_non_nginx
          ) : (
          var.enable_nginx[1] ? local.buildspec_frontend_ecs_fargate : local.buildspec_frontend_ecs_fargate_non_nginx
        )
        ) : (
        var.include_frontend_bucket ? local.buildspec_frontend_s3 : null
      )
    )
  }

  # Doc: https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-taskdefinition
  /* source {
    type      = "NO_SOURCE"
  #  buildspec = var.fargate_cluster == true && var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == false ? local.buildspec_frontend_ecs_fargate : var.fargate_cluster == false && var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == false ? local.buildspec_frontend_ecs_ec2 : var.include_frontend_ecs_service == false && var.include_frontend_bucket == true ? local.buildspec_frontend_s3 : var.include_frontend_ecs_service == true && var.include_frontend_bucket == false && var.enable_service_connect == true ? local.frontend_service_connect : : null
    buildspec = (
      var.include_frontend_ecs_service ? (
        var.fargate_cluster ? (
          var.enable_service_connect ? (
            var.enable_nginx[1] ? local.frontend_service_connect : local.frontend_service_connect_non_nginx
          ) : (
            var.enable_nginx[1] ? local.buildspec_frontend_ecs_fargate : local.buildspec_frontend_ecs_fargate_non_nginx
          )
        ) : (
          var.enable_service_connect ? (
            var.enable_nginx[1] ? local.frontend_service_connect : local.frontend_service_connect_non_nginx
          ) : (
            var.enable_nginx[1] ? local.buildspec_frontend_ecs_ec2 : local.buildspec_frontend_ecs_ec2_non_nginx
          )
        )
      ) : (
        var.include_frontend_bucket ? local.buildspec_frontend_s3 : null
      )
    )
  }
  */
}
