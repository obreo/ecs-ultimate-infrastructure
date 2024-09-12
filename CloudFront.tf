# Will Connect to S3 static site
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control
# Doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
resource "aws_cloudfront_origin_access_control" "oac" {
  count                             = var.include_frontend_bucket == true ? 1 : 0
  name                              = "${var.name[0]}-oac"
  description                       = "OAC access for ${var.name[0]}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "distribution" {
  count = var.include_frontend_bucket == true || var.force_HTTPS[0] == false && var.disable_autoscaling[0] == "false" ? 1 : 0
  origin {
    domain_name              = var.include_frontend_bucket == true ? aws_s3_bucket.bucket[count.index].bucket_regional_domain_name : aws_lb.load_balancer[count.index].dns_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac[count.index].id
    origin_id                = var.name[0]
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = var.name[0]
    viewer_protocol_policy = "allow-all" # For HTTP & HTTPS
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/mainDeveloperGuide/using-managed-cache-policies.html
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html#managed-response-headers-policies-cors
    response_headers_policy_id = "5cc3b908-e619-4b99-88e5-2cf7f45965bd"
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Project     = "${var.name[0]}"
    Environment = var.name[1] != "" ? "${var.name[1]}" : null
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
