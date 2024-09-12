# Creating lables for two environments:
locals {
  environment_names = ["${var.name[0]}"] // Replace with your ECS service names

  frontend_environment_names = ["${var.name[0]}-frontend"]
}