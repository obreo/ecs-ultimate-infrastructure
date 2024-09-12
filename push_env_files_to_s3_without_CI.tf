# This is used to run SSM secrets from a parameter store without CICD. Useful for images used without ECR registry
# In case these resources were not used and cicd not used for storing ssm parameters to s3, then push the .env file to the artifacs bucket and update the services with the same tasks.
# Backend
resource "null_resource" "backend_ssm_execution" {
  count = var.include_application_registry[0] == "false" && var.env_path[0] != "" ? 1 : 0
  provisioner "local-exec" {
    environment = {
      AWS_PROFILE                 = " "
      AWS_CONFIG_FILE             = "${path.module}/.aws/config"
      AWS_SHARED_CREDENTIALS_FILE = "${path.module}/.aws/credentials"
    }
    command = <<EOT
    aws s3 cp "${var.env_path[0]}" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}/.env"
    EOT
  }
}

# Frontend
resource "null_resource" "frontend_ssm_execution" {
  count = var.include_frontend_application_registry[0] == "false" && var.env_path[1] != "" ? 1 : 0
  provisioner "local-exec" {
    environment = {
      AWS_PROFILE                 = " "
      AWS_CONFIG_FILE             = "${path.module}/.aws/config"
      AWS_SHARED_CREDENTIALS_FILE = "${path.module}/.aws/credentials"
    }
    command = <<EOT
    aws s3 cp "${var.env_path[1]}" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}-frontend/.env"
    EOT
  }
}

