# Attach this role with codebuild application and check the option that allows role modification while codebuild app environment creation.


# Service Role to pass
resource "aws_iam_role" "codebuild-role" {
  name               = "codebuild-ecs-assume-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.codebuild-service-role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "codebuild-service-role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy_attachment" "AmazonECS_FullAccess" {
  name       = "codebuild_policy_1"
  roles      = [aws_iam_role.codebuild-role.name] # "${aws_iam_role.codebuild-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_policy_attachment" "codebuild_custom_policy" {
  name       = "codebuild_policy_2"
  roles      = [aws_iam_role.codebuild-role.name]
  policy_arn = aws_iam_policy.codebuild_custom_policy.arn
}

/*
resource "aws_iam_policy_attachment" "AmazonEC2RoleforSSM" {
  name       = "codebuild_policy_3"
  roles      = ["${aws_iam_role.codebuild-role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}
*/
####################################

resource "aws_iam_policy" "codebuild_custom_policy" {
  name        = "codebuild_custom_policy"
  path        = "/"
  description = "Additional policies required for codebuild cicd"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
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
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
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
      },
      {
        Sid    = "Additionals2"
        Effect = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ]
        Resource = [
          "arn:aws:codebuild:${var.region}:${var.account_id}:report-group/*"
        ]
      },
      {
        "Sid" : "AllowSSMParameterAccess",
        "Effect" : "Allow",
        "Action" : ["ssm:GetParametersByPath"]
        "Resource" : "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
      }
    ]
  })

}
