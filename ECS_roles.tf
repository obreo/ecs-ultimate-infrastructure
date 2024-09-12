######################################################
# Task Execution Role
# This is given to ECS to get the image and write logs in cloudwatch - role is executed on the task definition level.
######################################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

#Policy Attachment
# To get ECR image and write logs in cloudwatch
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# To get parameters from SSM - if needed
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}
# To create EBS volume- if needed
resource "aws_iam_role_policy_attachment" "ebs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}
# To get .env file from S3 bucket - if needed
resource "aws_iam_role_policy_attachment" "custom_ecs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.custom_ecs_policy.arn
}
resource "aws_iam_policy" "custom_ecs_policy" {
  name        = "custom_ecs_policy"
  path        = "/"
  description = "Additional policies given to ECS task and task execution"
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/*",
        ]
      }
    ]
  })

}

######################################################
# Task Role
# This is given to ECS tasks to execute AWS permissions inside the container - role is executed on the container level.
######################################################
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs_task_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "ecs_task_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

#Policy Attachment
# To get RDS - internal access
resource "aws_iam_role_policy_attachment" "rds" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}
# To get .env file from S3 bucket - if needed
resource "aws_iam_role_policy_attachment" "custom_ecs_policy_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.custom_ecs_policy.arn
}

#####################################################
# EC2 Cluster roles
#####################################################

data "aws_iam_policy_document" "ecs_ec2_role" {
  count = var.fargate_cluster == false ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ecs_node_role" {
  count              = var.fargate_cluster == false ? 1 : 0
  name_prefix        = "demo-ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_ec2_role[count.index].json
}

resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
  count      = var.fargate_cluster == false ? 1 : 0
  role       = aws_iam_role.ecs_node_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_ec2_instance" {
  count       = var.fargate_cluster == false ? 1 : 0
  name_prefix = "ecs-ec2-profile"
  path        = "/ecs/instance/"
  role        = aws_iam_role.ecs_node_role[count.index].name
}




