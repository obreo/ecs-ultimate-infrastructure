# Backend
#Pull code, build and deploy
resource "aws_codepipeline" "nginx" {
  count    = 0
  name     = "nginx"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[count.index].id : var.artifacts_bucket[1]
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
        FullRepositoryId = "${var.backend_resposiotry_id[0] != "" ? var.backend_resposiotry_id[0] : "NA"}"
        BranchName       = "${var.nginx_config_file[0] != "" ? var.nginx_config_file[0] : "NA"}"
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
        ProjectName = "${aws_codebuild_project.nginx[count.index].name}"
      }
    }
  }
}


# Frontend
resource "aws_codepipeline" "nginx_frontend" {
  count    = 0
  name     = "nginx-frontend"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[count.index].id : var.artifacts_bucket[1]
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
        FullRepositoryId = "${var.frontend_resposiotry_id[0] != "" ? var.frontend_resposiotry_id[0] : "NA"}"
        BranchName       = "${var.frontend_nginx_config_file[0] != "" ? var.frontend_nginx_config_file[0] : "NA"}"
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
        ProjectName = "${aws_codebuild_project.frontend_nginx[count.index].name}"
      }
    }
  }
}