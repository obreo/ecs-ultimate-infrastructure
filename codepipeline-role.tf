# Service Role
resource "aws_iam_role" "codepipeline" {
  name               = "${var.name[0]}-codepipeline-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_policy_attachment" "codepipeline" {
  name       = "codepipeline"
  roles      = ["${aws_iam_role.codepipeline.name}"]
  policy_arn = aws_iam_policy.codepipeline.arn
}

data "aws_iam_policy_document" "codepipeline" {
  version = "2012-10-17"

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "codepipeline" {
  name        = "codepipeline-role-policy"
  description = "Example IAM policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "passrole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" = [
              "cloudformation.amazonaws.com",
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com",
              "codedeploy.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid    = "codecommit"
        Effect = "Allow"
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ]
        Resource = "*"
      },
      {
        Sid    = "codedeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Sid      = "codestar"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = "*"
      },
      {
        Sid    = "Additionals"
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "lambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      },
      {
        Sid    = "opsworks"
        Effect = "Allow"
        Action = [
          "opsworks:CreateDeployment",
          "opsworks:DescribeApps",
          "opsworks:DescribeCommands",
          "opsworks:DescribeDeployments",
          "opsworks:DescribeInstances",
          "opsworks:DescribeStacks",
          "opsworks:UpdateApp",
          "opsworks:UpdateStack"
        ]
        Resource = "*"
      },
      {
        Sid    = "cloudformation"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ]
        Resource = "*"
      },
      {
        Sid    = "rest"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch",
          "devicefarm:ListProjects",
          "devicefarm:ListDevicePools",
          "devicefarm:GetRun",
          "devicefarm:GetUpload",
          "devicefarm:CreateUpload",
          "devicefarm:ScheduleRun",
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct",
          "cloudformation:ValidateTemplate",
          "ecr:DescribeImages",
          "states:DescribeExecution",
          "states:DescribeStateMachine",
          "states:StartExecution",
          "appconfig:StartDeployment",
          "appconfig:StopDeployment",
          "appconfig:GetDeployment"
        ]
        Resource = "*"
      }
    ]
  })
}

