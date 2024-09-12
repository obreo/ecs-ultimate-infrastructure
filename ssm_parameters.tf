
/*
NOTE: 
1. Use the same parameters path for all secrets.
2. Duplicate the resource with different resource names to add more secretes.
3. You can use the secret path in the ssm_parameters_path variable for both backend and frontend.
*/

# Backend
resource "aws_ssm_parameter" "secret" {
  count = var.include_ssm_parameter_resource[0] ? 1 : 0
  # Pattern: /Environment/ApplicationName/SecretName
  name  = "/${var.name[1]}/${var.name[0]}/"
  type  = "SecureString"
  value = ""

  tags = {
    environment = "${var.name[1]}"
  }
}




# Frontend
resource "aws_ssm_parameter" "frontend_secret" {
  count = var.include_ssm_parameter_resource[1] ? 1 : 0
  # Pattern: /Environment/ApplicationName/SecretName
  name  = "/${var.name[1]}/${var.name[0]}-frontend/"
  type  = "SecureString"
  value = ""

  tags = {
    environment = "${var.name[1]}"
  }
}