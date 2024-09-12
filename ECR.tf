# Application Image registry
resource "aws_ecr_repository" "ecr" {
  count                = var.include_application_registry[0] == "true" ? 1 : 0
  name                 = var.name[0]
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Frontend Appliaction Image registry
resource "aws_ecr_repository" "frontend_ecr" {
  count                = var.include_frontend_application_registry[0] == "true" ? 1 : 0
  name                 = "${var.name[0]}-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Nginx image
resource "aws_ecr_repository" "nginx" {
  count                = var.build_nginx_application[0] == "true" ? 1 : 0
  name                 = "nginx"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}