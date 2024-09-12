
# Doc: https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html
# Doc: https://docs.aws.amazon.com/codepipeline/latbucketest/userguide/action-reference.html

# S3
# Pull code and deplpoy
resource "aws_codepipeline" "frontend_s3" {
  count    = var.include_frontend_bucket == true ? 1 : 0
  name     = "${var.name[0]}-frontend"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket_artifact[count.index].bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "${aws_codestarconnections_connection.connection.arn}"
        FullRepositoryId = "${var.frontend_resposiotry_id[0]}"
        BranchName       = "${var.frontend_resposiotry_id[1]}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        BucketName = "${aws_s3_bucket.bucket[count.index].bucket}"
        Extract    = "false"
        Region     = "${var.region}"
      }
    }
  }
}


# S3 with CI
#Pull code, build and deploy
resource "aws_codepipeline" "frontend_s3_ci" {
  count    = var.include_frontend_bucket == true && var.include_codebuild_for_s3 == true ? 1 : 0
  name     = "${var.name[0]}-frontend"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket_artifact[count.index].bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "${aws_codestarconnections_connection.connection.arn}"
        FullRepositoryId = "${var.frontend_resposiotry_id[0]}"
        BranchName       = "${var.frontend_resposiotry_id[1]}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.codebuild_frontend[count.index].id}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = "${aws_s3_bucket.bucket[count.index].bucket}"
        Extract    = "false"
        Region     = "${var.region}"
      }
    }
  }
}

# ECS
#Pull code, build and deploy
resource "aws_codepipeline" "frontend_ecs" {
  count    = var.include_frontend_ecs_service == true && var.include_codebuild_for_s3 == false && var.include_frontend_bucket == false && var.frontend_resposiotry_id[0] != "" ? 1 : 0
  name     = "${var.name[0]}-frontend"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket_artifact[count.index].bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "${aws_codestarconnections_connection.connection.arn}"
        FullRepositoryId = "${var.frontend_resposiotry_id[0]}"
        BranchName       = "${var.frontend_resposiotry_id[1]}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.codebuild_frontend[count.index].id}"
      }
    }
  }

  dynamic "stage" {
    for_each = var.enable_service_connect ? [] : [1]
    content {
      name = "Deploy"

      action {
        name     = "Deploy"
        category = "Deploy"
        owner    = "AWS"
        provider = "CodeDeployToECS"
        version  = "1"

        configuration = {
          AppSpecTemplateArtifact        = "build_output"
          TaskDefinitionTemplateArtifact = "build_output"
          TaskDefinitionTemplatePath     = "${var.include_external_taskdefinition_file[1] ? "${var.external_taskdefinition_file[1]}" : "taskdef.json"}"
          AppSpecTemplatePath            = "appspec.yaml"
          ApplicationName                = "${aws_codedeploy_app.app[count.index].name}"
          DeploymentGroupName            = "${var.name[0]}-frontend"
          Image1ArtifactName             = "build_output"
          Image1ContainerName            = "IMAGE1_NAME"
        }
        input_artifacts = ["build_output"]
      }
    }
  }
}