locals {
  # Note: Task definition used for the taskdefinition resource includes ONLY container configuration and not task related configs as they are mentioned in the Task definition Parameters.
  # BACKEND
  # 1. with nginx
  backend_task_def = <<EOF
[
  {
    "name": "${var.name[0]}",
    "image": "${var.include_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:latest" : var.include_application_registry[1]}",
    "essential": true,
    "cpu": ${var.backend_ecs_config[1]},
    "memory": ${var.backend_ecs_config[2] / 2},
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
        "name": "${var.name[0]}",
        "containerPort": ${var.backend_ecs_config[0]},
        "hostPort": ${var.backend_ecs_config[0]},
        "protocol": "tcp",
        "appProtocol": "http"           
      }
    ]
  },
  {
    "name": "nginx",
    "image": "${var.build_nginx_application[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}" : var.build_nginx_application[1]}",
    "cpu": 0,
    "portMappings": [
        {
        "name": "nginx",
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp",
        "appProtocol": "http"
        }
    ],
    "essential": true,
    "dependsOn": [
        {
            "containerName": "${var.name[0]}",
            "condition": "START"
        }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "/ecs/${var.name[0]}/nginx",
            "awslogs-create-group": "true",
            "awslogs-region": "${var.region}",
            "awslogs-stream-prefix": "ecs"
        }
    },
    "healthCheck": {
        "command": [
            "CMD-SHELL",
            "curl -f http://localhost/ || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3
    },
    "entryPoint": [
      "sh",
      "-c",
      "sleep 30 && nginx -g 'daemon off;'"
    ]
  } 
]

EOF


  # WITHOUT NGINX

  backend_task_def_non_nginx = <<EOF
[
  {
    "name": "${var.name[0]}",
    "image": "${var.include_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:latest" : var.include_application_registry[1]}",
    "essential": true,
    "cpu":  ${var.backend_ecs_config[1]},
    "memory": ${var.backend_ecs_config[2] / 2},
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
        "name": "${var.name[0]}",
        "containerPort": ${var.use_port_80_in_nonnginx_taskdef == false ? var.backend_ecs_config[0] : 80},
        "hostPort": ${var.use_port_80_in_nonnginx_taskdef == false ? var.backend_ecs_config[0] : 80},
        "protocol": "tcp",
        "appProtocol": "http"           
      }
    ]
  }
]

EOF




  # FRONTEND
  # 1. with nginx
  frontend_task_def = <<EOF
[
  {
    "name": "${var.name[0]}-frontend",
    "image": "${var.include_frontend_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:latest" : var.include_frontend_application_registry[1]}",
    "essential": true,
    "cpu": ${var.frontend_ecs_config[1]},
    "memory": ${var.frontend_ecs_config[2] / 2},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.name[0]}-frontend/task",
        "awslogs-create-group": "true",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "environmentFiles": [
      {
        "value": "arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}-frontend/.env",
        "type": "s3"
      }
    ],
    "portMappings": [
      {
        "name": "${var.name[0]}-frontend",
        "containerPort": ${var.frontend_ecs_config[0]},
        "hostPort": ${var.frontend_ecs_config[0]},
        "protocol": "tcp",
        "appProtocol": "http"
      }
    ]
  },
  {
    "name": "nginx",
    "image": "${var.build_nginx_application[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.nginx[0].name}:${var.name[0]}-frontend" : var.build_nginx_application[2]}",
    "cpu": 0,
    "portMappings": [
      {
        "name": "nginx-80-tcp",
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp",
        "appProtocol": "http"
      }
    ],
    "essential": true,
    "dependsOn": [
      {
        "containerName": "${var.name[0]}-frontend",
        "condition": "START"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.name[0]}-frontend/nginx",
        "awslogs-create-group": "true",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": [
        "CMD-SHELL",
        "curl -f http://localhost/ || exit 1"
      ],
      "interval": 30,
      "timeout": 5,
      "retries": 3
    },
    "entryPoint": [
      "sh",
      "-c",
      "sleep 30 && nginx -g 'daemon off;'"
    ]
  }
]

EOF


  # WITHOUT NGINX

  frontend_task_def_non_nginx = <<EOF
[
  {
    "name": "${var.name[0]}-frontend",
    "image": "${var.include_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:latest" : var.include_application_registry[1]}",
    "essential": true,
    "cpu": ${var.frontend_ecs_config[1]},
    "memory": ${var.frontend_ecs_config[2] / 2},
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
        "name": "${var.name[0]}-frontend",
        "containerPort": ${var.use_port_80_in_nonnginx_taskdef == false ? var.frontend_ecs_config[0] : 80},
        "hostPort": ${var.use_port_80_in_nonnginx_taskdef == false ? var.frontend_ecs_config[0] : 80},
        "protocol": "tcp",
        "appProtocol": "http"           
      }
    ]
  }
]

EOF


}
