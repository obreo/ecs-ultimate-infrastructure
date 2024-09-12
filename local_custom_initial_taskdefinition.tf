locals {
  # Note: Task definition used for the taskdefinition resource includes ONLY container configuration and not task related configs as they are mentioned in the Task definition Parameters.
  # BACKEND
  custom_backend_task_def = <<EOF
[
  {
    "name": "",
    "image": "",
    "essential": true,
    "cpu": ,
    "memory": ,
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "/ecs/${var.name[0]}/task",
            "awslogs-create-group": "true",
            "awslogs-region": "${var.region}",
            "awslogs-stream-prefix": "ecs"
          }
    },
    "environmentFiles": [
      {
        "value": "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}/.env",
        "type": "s3"
      }
    ],
    "portMappings": [
      {
        "name": "",
        "containerPort": ,
        "hostPort": ,
        "protocol": "tcp",
        "appProtocol": "http"           
      }
    ]
  }
]

EOF

  # BACKEND
  custom_frontend_task_def = <<EOF
[
  {
    "name": "",
    "image": "",
    "essential": true,
    "cpu": ,
    "memory": ,
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "/ecs/${var.name[0]}/task",
            "awslogs-create-group": "true",
            "awslogs-region": "${var.region}",
            "awslogs-stream-prefix": "ecs"
          }
    },
    "environmentFiles": [
      {
        "value": "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}/.env",
        "type": "s3"
      }
    ],
    "portMappings": [
      {
        "name": "",
        "containerPort": ,
        "hostPort": ,
        "protocol": "tcp",
        "appProtocol": "http"           
      }
    ]
  }
]

EOF
}