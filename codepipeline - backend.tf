# ECS
#Pull code, build and deploy
resource "aws_codepipeline" "backend_ecs" {
  count    = var.backend_resposiotry_id[0] == "" ? 0 : 1
  name     = var.name[0]
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
        FullRepositoryId = "${var.backend_resposiotry_id[0]}"
        BranchName       = "${var.backend_resposiotry_id[1]}"
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
        ProjectName = "${aws_codebuild_project.codebuild[count.index].id}"
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
          TaskDefinitionTemplatePath     = "${var.include_external_taskdefinition_file[0] ? "${var.external_taskdefinition_file[0]}" : "taskdef.json"}"
          AppSpecTemplatePath            = "appspec.yaml"
          ApplicationName                = "${aws_codedeploy_app.app[count.index].name}"
          DeploymentGroupName            = "${var.name[0]}"
          Image1ArtifactName             = "build_output"
          Image1ContainerName            = "IMAGE1_NAME"
        }
        input_artifacts = ["build_output"]
      }
    }
  }

}