# This resource is used to push code artifacts and store environment variables securely.
# S3 Bucket
resource "aws_s3_bucket" "bucket_artifact" {
  count         = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket        = "${var.name[0]}-artifacts"
  force_destroy = true
}

resource "aws_s3_bucket_object" "folder" {
  count  = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket = aws_s3_bucket.bucket_artifact[count.index].id
  key    = "secrets/${var.name[0]}/"
}

resource "aws_s3_bucket_object" "folder_frontend" {
  count  = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket = aws_s3_bucket.bucket_artifact[count.index].id
  key    = "secrets/${var.name[0]}-frontend/"
}

# Disabling bucket ACLs 
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
resource "aws_s3_bucket_ownership_controls" "ownership" {
  count  = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket = aws_s3_bucket.bucket_artifact[count.index].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Blocking public access - restricting access to CloudFront with OAC
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl
resource "aws_s3_bucket_public_access_block" "public_access" {
  count                   = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket                  = aws_s3_bucket.bucket_artifact[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## Bucket policy
resource "aws_s3_bucket_policy" "allow_access" {
  count  = var.artifacts_bucket[0] == "true" ? 1 : 0
  bucket = aws_s3_bucket.bucket_artifact[count.index].id
  policy = data.aws_iam_policy_document.allow_access_artifact[count.index].json
}

data "aws_iam_policy_document" "allow_access_artifact" {
  count = var.artifacts_bucket[0] == "true" ? 1 : 0
  statement {
    principals {
      type = "Service"
      identifiers = [
        "codedeploy.amazonaws.com",
        "codebuild.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.bucket_artifact[0].arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["${var.account_id}"]
    }
  }
}
