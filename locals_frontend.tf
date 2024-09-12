locals {
  # ECS: used when frontend for ECS is enabled.


  # 1
  # ECS Fargate: Frontend & EC2 Frontend
  buildspec_frontend_ecs_fargate = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
      # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
      version: 0.2
      phases:
        pre_build:
          commands:
            # Log in ECR registry
            - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

            # Calling SSM parameters and storing them in .env file (Using either command below)
            #- while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.ssm_parameters_path[1]}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
            - ${var.ssm_parameters_path[1] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[1]} --with-decryption --query 'Parameters[*].[Name,Value]' --output text | while read -r name value; do exported_variables=\"$${name##*/}=$value\"; echo '$exported_variables' >> .env; done" : "touch .env"}
        
        build:
          commands:
            # Pulling image
            #- echo  'Pulling Image'
            #- docker pull <IMAGE_NAME>

            # Building Dockerfile
            # Note: To run envrionment variables during build, Dockerfile will have an image builder that will run the application that uses .env file created earlier, a second image will copy the compiled files without .env, where the ECS will use .env file stored in S3 bucket instead.
            - echo 'Building dockerfile'
            - docker build -t ${var.name[0]}-frontend .

            # Creating a new task definition - Image for Nginx as a proxy server, another for the application
            - echo 'Creating task-definition.json file'
            - |
              cat << 'END' > taskdef.json
              {
                "family": "${var.name[0]}-frontend",
                "networkMode": "awsvpc",
                "requiresCompatibilities": ["FARGATE", "EC2"],
                "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
                "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
                "cpu": "${var.frontend_ecs_config[1]}",
                "memory": "${var.frontend_ecs_config[2]}",
                "runtimePlatform": {
                    "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
                    "operatingSystemFamily": "LINUX"
                },
                "containerDefinitions": [
                  {
                    "name": "${var.name[0]}-frontend",
                    "image": "<IMAGE1_NAME>",
                    "essential": true,
                    "cpu": 0,
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
                        "value": ""arn:aws:s3:::${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}-frontend/.env",
                        "type": "s3"
                      }
                    ],
                    "portMappings": [
                      {
                        "name": "${var.name[0]}-frontend,
                        "containerPort": ${var.frontend_ecs_config[0]},
                        "hostPort": ${var.frontend_ecs_config[0]},
                        "protocol": "tcp",
                        "appProtocol": "http"           
                      }
                    ]
                  },
                  {
                  "name": "nginx",
                  "image": "${var.build_nginx_application[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend" : var.build_nginx_application[2]}",
                  "cpu": 0,
                  "memory": 256,
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
                  }
                ]
              }
              END

        post_build:
          commands:
            # Pushing image to repository
            - echo 'Pushing Image to ECR repository & updating the image tag'
            - docker tag ${var.name[0]}:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}
            - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}

            # Pushing .env file to s3 bucket
            - echo 'Pushing .env file to s3 bucket'
            - aws s3 mv "./.env" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}-frontend/.env

            # updating task definition IN ECS
            #- echo "updating task definition..."
            #- aws ecs register-task-definition --region ${var.region} --cli-input-json file://taskdef.json --query 'taskDefinition.taskDefinitionArn' --output text
            #- REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]}-frontend --query 'taskDefinition.revision')


            # Write the new appspec.yaml
            - echo "Building appspec.yaml"
            - |
              cat > appspec.yaml << 'END'
              version: 0.0
              Resources:
                - TargetService:
                    Type: AWS::ECS::Service
                    Properties:
                      TaskDefinition: <TASK_DEFINITION>
                      LoadBalancerInfo:
                        ContainerName: "nginx"
                        ContainerPort: 80
              END
            # Generating imageDetail.json file to define the image uri:
            - printf '{"ImageURI":"${var.include_frontend_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend%s:'$${CODEBUILD_BUILD_NUMBER}'" : var.include_frontend_application_registry[1]}"}' > imageDetail.json
      artifacts:
        files:
          - ${var.include_external_taskdefinition_file[1] ? "${var.external_taskdefinition_file[1]}" : "taskdef.json"}
          - appspec.yaml
          - imageDetail.json
  EOF

  # Fargate frontend but wihtout nginx
  buildspec_frontend_ecs_fargate_non_nginx = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
# Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
version: 0.2
phases:
  pre_build:
    commands:
      # Log in ECR registry
      - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

      # Calling SSM parameters and storing them in .env file (Using either command below)
      #- while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.ssm_parameters_path[1]}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
      - ${var.ssm_parameters_path[1] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[1]} --with-decryption --query 'Parameters[*].[Name,Value]' --output text | while read -r name value; do exported_variables=\"$${name##*/}=$value\"; echo '$exported_variables' >> .env; done" : "touch .env"}
  
  build:
    commands:
      # Pulling image
      #- echo  'Pulling Image'
      #- docker pull <IMAGE_NAME>

      # Building Dockerfile
      # Note: To run envrionment variables during build, Dockerfile will have an image builder that will run the application that uses .env file created earlier, a second image will copy the compiled files without .env, where the ECS will use .env file stored in S3 bucket instead.
      - echo 'Building dockerfile'
      - docker build -t ${var.name[0]}-frontend .

      # Creating a new task definition - Image for Nginx as a proxy server, another for the application
      - echo 'Creating task-definition.json file'
      - |
        cat << 'END' > taskdef.json
        {
          "family": "${var.name[0]}-frontend",
          "networkMode": "awsvpc",
          "requiresCompatibilities": ["FARGATE", "EC2"],
          "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
          "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
          "cpu": "${var.frontend_ecs_config[1]}",
          "memory": "${var.frontend_ecs_config[2]}",
          "runtimePlatform": {
              "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
              "operatingSystemFamily": "LINUX"
          },
          "containerDefinitions": [
            {
              "name": "${var.name[0]}-frontend",
              "image": "<IMAGE1_NAME>",
              "essential": true,
              "cpu": 0,
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
            }
          ]
        }
        END

  post_build:
    commands:
      # Pushing image to repository
      - echo 'Pushing Image to ECR repository & updating the image tag'
      - docker tag ${var.name[0]}-frontend:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}
      - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}

      # Pushing .env file to s3 bucket
      - echo 'Pushing .env file to s3 bucket'
      - aws s3 mv "./.env" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}-frontend/.env

      # updating task definition IN ECS
      #- echo "updating task definition..."
      #- aws ecs register-task-definition --region ${var.region} --cli-input-json file://taskdef.json --query 'taskDefinition.taskDefinitionArn' --output text
      #- REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]}-frontend --query 'taskDefinition.revision')


      # Write the new appspec.yaml
      - echo "Building appspec.yaml"
      - |
        cat > appspec.yaml << 'END'
        version: 0.0
        Resources:
          - TargetService:
              Type: AWS::ECS::Service
              Properties:
                TaskDefinition: <TASK_DEFINITION>
                LoadBalancerInfo:
                  ContainerName: "${var.name[0]}-frontend"
                  ContainerPort: 80
        END
      # Generating imageDetail.json file to define the image uri:
      - printf '{"ImageURI":"${var.include_frontend_application_registry[0] == "true" ? "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend%s:'$${CODEBUILD_BUILD_NUMBER}'" : var.include_frontend_application_registry[1]}"}' > imageDetail.json

artifacts:
  files:
    - ${var.include_external_taskdefinition_file[1] ? "${var.external_taskdefinition_file[1]}" : "taskdef.json"}
    - appspec.yaml
    - imageDetail.json
EOF


  # 2
  # S3: used when frontend for s3 is enabled
  buildspec_frontend_s3 = <<EOF
  This script will build nodejs app, and push it as an artifact considering all files in a single folder. This is used for S3 static sites.

  version: 0.2
  phases:
    install:
        runtime-versions:
                nodejs: 18
    pre_build:
        commands:
          - echo 'calling parameters'
          - ${var.ssm_parameters_path[1] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[1]} --with-decryption --query 'Parameters[*].[Name,Value]' --output text | while read -r name value; do exported_variables='$${name##*/}=$value'; echo '$exported_variables' >> .env; done" : "echo no env stated."}
          - echo Installing source NPM dependencies... 
          - npm install --force
    build:
        commands:
          - echo Build started 
          - npm run build
  artifacts:
    name: artifact
    files:
      - '**/*'
    base-directory: "dist"
    discard-path: yes
    artifact_bucket: ${var.name[0]}-frontend}
    EOF
}