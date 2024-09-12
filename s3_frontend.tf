# S3 Bucket for the frontend tier - optional
# This resource is used to run applicatioon's frontend by storing the application's code in S3 bucket and restrict viewing it to CloudFront using OAC.
# Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html

# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "bucket" {
  count  = var.include_frontend_bucket == true && var.include_frontend_ecs_service == false ? 1 : 0
  bucket = "${var.name[0]}-frontend"
}

# Disabling bucket ACLs 
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
resource "aws_s3_bucket_ownership_controls" "example" {
  count  = var.include_frontend_bucket == true && var.include_frontend_ecs_service == false ? 1 : 0
  bucket = aws_s3_bucket.bucket[count.index].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Blocking public access - restricting access to CloudFront with OAC
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl
resource "aws_s3_bucket_public_access_block" "example" {
  count                   = var.include_frontend_bucket == true && var.include_frontend_ecs_service == false ? 1 : 0
  bucket                  = aws_s3_bucket.bucket[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Bucket policy
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
resource "aws_s3_bucket_policy" "allow_access_static" {
  count  = var.include_frontend_bucket == true && var.include_frontend_ecs_service == false ? 1 : 0
  bucket = aws_s3_bucket.bucket[count.index].id
  policy = data.aws_iam_policy_document.allow_access_static[count.index].json
}

data "aws_iam_policy_document" "allow_access_static" {
  count = var.include_frontend_bucket == true && var.include_frontend_ecs_service == false ? 1 : 0
  statement {
    principals {
      type        = "service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.bucket[count.index].arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["${aws_cloudfront_distribution.distribution[count.index].arn}"]
    }
  }

  statement {
    principals {
      type        = "service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.bucket[count.index].arn}/*"
    ]
  }
}


/*
# S3 Objects
# Doc: https://stackoverflow.com/questions/76170291/how-do-i-specify-multiple-content-types-to-my-s3-object-using-terraform
locals {
  folder_path = "./frontend" # Update this with the path to your folder
  files       = fileset(local.folder_path, "**/ /*")
  # Content type mappings
  content_type_map = {
    ".js"          = "text/javascript"
    ".map"         = "binary/octet-stream"
    ".png"         = "image/png"
    ".svg"         = "image/svg+xml"
    ".mjs"         = "text/javascript"
    ".css"         = "text/css"
    ".jpg"         = "image/jpeg"
    ".woff2"       = "binary/octet-stream"
    ".ico"         = "image/x-icon"
    ".txt"         = "text/plain"
    ".webmanifest" = "binary/octet-stream"
    ".html"        = "text/html"
    # Add more mappings as needed
  }
}

resource "aws_s3_bucket_object" "object" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "text/javascript")
}

resource "aws_s3_bucket_object" "object2" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "binary/octet-stream")
}

resource "aws_s3_bucket_object" "object3" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "image/png")
}

resource "aws_s3_bucket_object" "object4" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "image/svg+xml")
}

resource "aws_s3_bucket_object" "object5" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "text/css")
}

resource "aws_s3_bucket_object" "object6" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "image/jpeg")
}

resource "aws_s3_bucket_object" "object7" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "image/x-icon")
}

resource "aws_s3_bucket_object" "object8" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "text/plain")
}

resource "aws_s3_bucket_object" "object9" {
  for_each     = { for file in local.files : file => file }
  bucket       = aws_s3_bucket.bucket.id
  key          = each.value
  source       = "${local.folder_path}/${each.value}"
  etag         = filemd5("${local.folder_path}/${each.value}")
  content_type = lookup(local.content_type_map, split(".", "${local.folder_path}/${each.value}")[1], "text/html")
}
*/

/*
resource "aws_s3_object" "object" {
  for_each = { for file in local.files : file => file }
  bucket   = aws_s3_bucket.bucket.id
  key      = each.value
  source   = "${local.folder_path}/${each.value}"
}
*/