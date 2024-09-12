locals {
  # When service connect is enabled for backend
  ###################################################################################################################################################################################################
  # BACKEND
  ###################################################################################################################################################################################################
  backend_service_connect = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
      # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
      version: 0.2
      env:
        variables:
          ecsCluster: ${aws_ecs_cluster.cluster.name}
          ecsService: ${var.name[0]}
      phases:
        pre_build:
          commands:
            # Log in ECR registry
            - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

            # Calling SSM parameters and storing them in .env file (Using either command below)
            #- while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.ssm_parameters_path[0]}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
            - ${var.ssm_parameters_path[0] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[0]} --with-decryption --query Parameters[*].[Name,Value] --output text | while read -r name value; do exported_variables=\"$${name##*/}=$value\"; echo $exported_variables >> .env; done" : "touch .env"}
        
        build:
          commands:
            # Pulling image
            #- echo  'Pulling Image'
            #- docker pull <IMAGE_NAME>

            # Building Dockerfile
            # Note: To run envrionment variables during build, Dockerfile will have an image builder that will run the application that uses .env file created earlier, a second image will copy the compiled files without .env, where the ECS will use .env file stored in S3 bucket instead.
            - echo 'Building dockerfile'
            - docker build -t ${var.name[0]} .

            # Creating a new task definition - Image for Nginx as a proxy server, another for the application
            - echo 'Creating task-definition.json file'
            - |
              cat <<END > taskdef.json
              {
                "family": "${var.name[0]}",
                "networkMode": "awsvpc",
                "requiresCompatibilities": [${var.include_efs_ebs_bind[3] == "true" ? "\"FARGATE\"" : "\"FARGATE\", \"EC2\""}],
                "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
                "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
                "cpu": "${var.backend_ecs_config[1]}",
                "memory": "${var.backend_ecs_config[2]}",
                "runtimePlatform": {
                  "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
                  "operatingSystemFamily": "LINUX"
                },
                ${var.include_efs_ebs_bind[3] == "true" ? trimspace(<<EOF
                "ephemeralStorage":
                  {
                    "sizeInGiB": ${tonumber(var.storage_details[0])}
                  },
                  EOF
                  ) : ""}
                "volumes":${var.include_efs_ebs_bind[0] == "true" ? trimspace(<<EOF
                  [{
                    "name" : "efs-${var.name[0]}",
                    "efsVolumeConfiguration" : {
                      "fileSystemId" : "${var.efs_details[0]}",
                      "transitEncryption" : "ENABLED"
                    }
                  }],
                  EOF
                  ) : "${var.include_efs_ebs_bind[1] == "true"}" ? trimspace(<<EOF
                  [{
                    "name" : "ebs-bind-${var.name[0]}",
                    "configuredAtLaunch" : true
                  }],
                  EOF
                  ) : "${var.include_efs_ebs_bind[2] == "true"}" ? trimspace(<<EOF
                  [{
                    "name" : "ebs-bind-${var.name[0]}",
                    "host" :  {}
                  }],
                  EOF
                  ) :"[],"}
                "containerDefinitions": [
                  {
                    "name": "${var.name[0]}",
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:$${CODEBUILD_BUILD_NUMBER}",
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
                    "mountPoints":${var.include_efs_ebs_bind[0] == "true"? trimspace(<<EOF
                    [{
                      "containerPath : "${var.efs_details[1]}",
                      "sourceVolume : "efs-${var.name[0]}"
                    }],
                    EOF 
                    ) : "${var.include_efs_ebs_bind[1] == "true"}" || "${var.include_efs_ebs_bind[2] == "true"}" ? trimspace( <<EOF
                    [{
                      "sourceVolume" : "ebs-bind-${var.name[0]}",
                      "containerPath" : "${var.storage_details[1]}",
                      "readOnly" : false
                    }],
                    EOF
                    ) : "[],"}
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
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}",
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
              }
              END

        post_build:
          commands:
            # Pushing image to repository
            - echo 'Pushing Image to ECR repository & updating the image tag'
            - docker tag ${var.name[0]}:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:$${CODEBUILD_BUILD_NUMBER}
            - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:$${CODEBUILD_BUILD_NUMBER}

            # Pushing .env file to s3 bucket
            - echo 'Pushing .env file to s3 bucket'
            - aws s3 mv "./.env" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}/.env

            # updating task definition IN ECS
            - echo "updating task definition..."
            - aws ecs register-task-definition --region ${var.region} --cli-input-json ${var.include_external_taskdefinition_file[0] ? "file://${var.external_taskdefinition_file[0]}" : "file://taskdef.json"} --query 'taskDefinition.taskDefinitionArn' --output text
            - REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]} --query 'taskDefinition.revision')
            - echo 'Stopping current running tasks..'
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --desired-count 0
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --deployment-configuration maximumPercent=100,minimumHealthyPercent=0
            - aws ecs update-service --region ${var.region} --service $${ecsService} --cluster $${ecsCluster} --task-definition ${var.name[0]}:$REVISION --force-new-deployment --desired-count 1                      

  EOF

# Without Nginx
backend_service_connect_non_nginx = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
      # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
      version: 0.2
      env:
        variables:
          ecsCluster: ${aws_ecs_cluster.cluster.name}
          ecsService: ${var.name[0]}
      phases:
        pre_build:
          commands:
            # Log in ECR registry
            - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

            # Calling SSM parameters and storing them in .env file (Using either command below)
            #- while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.ssm_parameters_path[0]}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
            - ${var.ssm_parameters_path[0] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[0]} --with-decryption --query Parameters[*].[Name,Value] --output text | while read -r name value; do exported_variables=\"$${name##*/}=$value\"; echo $exported_variables >> .env; done" : "touch .env"}
        
        build:
          commands:
            # Pulling image
            #- echo  'Pulling Image'
            #- docker pull <IMAGE_NAME>

            # Building Dockerfile
            # Note: To run envrionment variables during build, Dockerfile will have an image builder that will run the application that uses .env file created earlier, a second image will copy the compiled files without .env, where the ECS will use .env file stored in S3 bucket instead.
            - echo 'Building dockerfile'
            - docker build -t ${var.name[0]} .

            # Creating a new task definition - Image for Nginx as a proxy server, another for the application
            - echo 'Creating task-definition.json file'
            - |
              cat <<END > taskdef.json
              {
                "family": "${var.name[0]}",
                "networkMode": "awsvpc",
                "requiresCompatibilities": [${var.include_efs_ebs_bind[3] == "true" ? "\"FARGATE\"" : "\"FARGATE\", \"EC2\""}],
                "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
                "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
                "cpu": "${var.backend_ecs_config[1]}",
                "memory": "${var.backend_ecs_config[2]}",
                "runtimePlatform": {
                  "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
                  "operatingSystemFamily": "LINUX"
                },
                ${var.include_efs_ebs_bind[3] == "true" ? trimspace(<<EOF
                "ephemeralStorage":
                  {
                    "sizeInGiB": ${tonumber(var.storage_details[0])}
                  },
                  EOF
                  ) : ""}
                "volumes":${var.include_efs_ebs_bind[0] == "true" ? trimspace(<<EOF
                  [{
                    "name" : "efs-${var.name[0]}",
                    "efsVolumeConfiguration" : {
                      "fileSystemId" : "${var.efs_details[0]}",
                      "transitEncryption" : "ENABLED"
                    }
                  }],
                  EOF
                  ) : "${var.include_efs_ebs_bind[1] == "true"}" ? trimspace(<<EOF
                  [{
                    "name" : "ebs-bind-${var.name[0]}",
                    "configuredAtLaunch" : true
                  }],
                  EOF
                  ) : "${var.include_efs_ebs_bind[2] == "true"}" ? trimspace(<<EOF
                  [{
                    "name" : "ebs-bind-${var.name[0]}",
                    "host" :  {}
                  }],
                  EOF
                  ) :"[],"}
                "containerDefinitions": [
                  {
                    "name": "${var.name[0]}-frontend",
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:\$${CODEBUILD_BUILD_NUMBER}",
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
                    "mountPoints":${var.include_efs_ebs_bind[0] == "true"? trimspace(<<EOF
                    [{
                      "containerPath : "${var.efs_details[1]}",
                      "sourceVolume : "efs-${var.name[0]}"
                    }],
                    EOF 
                    ) : "${var.include_efs_ebs_bind[1] == "true"}" || "${var.include_efs_ebs_bind[2] == "true"}" ? trimspace( <<EOF
                    [{
                      "sourceVolume" : "ebs-bind-${var.name[0]}",
                      "containerPath" : "${var.storage_details[1]}",
                      "readOnly" : false
                    }],
                    EOF
                    ) : "[],"}
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
                  }
                ]
              }
              END

        post_build:
          commands:
            # Pushing image to repository
            - echo 'Pushing Image to ECR repository & updating the image tag'
            - docker tag ${var.name[0]}:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:$${CODEBUILD_BUILD_NUMBER}
            - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}:$${CODEBUILD_BUILD_NUMBER}

            # Pushing .env file to s3 bucket
            - echo 'Pushing .env file to s3 bucket'
            - aws s3 mv "./.env" s3://${var.artifacts_bucket[0] == "true" ? aws_s3_bucket.bucket_artifact[0].bucket : var.artifacts_bucket[1]}/secrets/${var.name[0]}/.env

            # updating task definition IN ECS
            - echo "updating task definition..."
            - aws ecs register-task-definition --region ${var.region} --cli-input-json ${var.include_external_taskdefinition_file[0] ? "file://${var.external_taskdefinition_file[0]}" : "file://taskdef.json"} --query 'taskDefinition.taskDefinitionArn' --output text
            - REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]} --query 'taskDefinition.revision')
            - echo 'Stopping current running tasks..'
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --desired-count 0
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --deployment-configuration maximumPercent=100,minimumHealthyPercent=0
            - aws ecs update-service --region ${var.region} --service $${ecsService} --cluster $${ecsCluster} --task-definition ${var.name[0]}:$REVISION --force-new-deployment --desired-count 1                      

  EOF


###################################################################################################################################################################################################
# FRONTEND
###################################################################################################################################################################################################
frontend_service_connect = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
      # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
      version: 0.2
      env:
        variables:
          ecsCluster: ${aws_ecs_cluster.cluster.name}
          ecsService: ${var.name[0]}
      phases:
        pre_build:
          commands:
            # Log in ECR registry
            - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

            # Calling SSM parameters and storing them in .env file (Using either command below)
            #- while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.ssm_parameters_path[1]}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
            - ${var.ssm_parameters_path[1] != "" ? "aws ssm get-parameters-by-path --path ${var.ssm_parameters_path[1]} --with-decryption --query Parameters[*].[Name,Value] --output text | while read -r name value; do exported_variables=\"$${name##*/}=$value\"; echo $exported_variables >> .env; done" : "touch .env"}
        
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
              cat <<END > taskdef.json
              {
                "family": "${var.name[0]}-frontend",
                "networkMode": "awsvpc",
                "requiresCompatibilities": ["FARGATE", "EC2"],
                "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
                "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
                "cpu": ${var.frontend_ecs_config[1]},
                "memory": "${var.frontend_ecs_config[2]}",
                "runtimePlatform": {
                    "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
                    "operatingSystemFamily": "LINUX"
                },
                "containerDefinitions": [
                  {
                    "name": "${var.name[0]}-frontend-frontend",
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}",
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
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend",
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
            - echo "updating task definition..."
            - aws ecs register-task-definition --region ${var.region} --cli-input-json ${var.include_external_taskdefinition_file[1] ? "file://${var.external_taskdefinition_file[1]}" : "file://taskdef.json"} --query 'taskDefinition.taskDefinitionArn' --output text
            - REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]}-frontend --query 'taskDefinition.revision')
            - echo 'Stopping current running tasks..'
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --desired-count 0
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --deployment-configuration maximumPercent=100,minimumHealthyPercent=0
            - aws ecs update-service --region ${var.region} --service $${ecsService} --cluster $${ecsCluster} --task-definition ${var.name[0]}-frontend:$REVISION --force-new-deployment --desired-count 1                      

  EOF


# without nginx
frontend_service_connect_non_nginx = <<EOF
# This is a buildspec script will build dockerfile image, then tag it and push it to ecr. Then write task-definition.json and register it to the ecs tasks, then write appspec.yml and store it with task-definition.json as artifacts.
      # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
      version: 0.2
      env:
        variables:
          ecsCluster: ${aws_ecs_cluster.cluster.name}
          ecsService: ${var.name[0]}
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
              cat <<END > taskdef.json
              {
                "family": "${var.name[0]}-frontend",
                "networkMode": "awsvpc",
                "requiresCompatibilities": ["FARGATE", "EC2"],
                "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}",
                "taskRoleArn": "${aws_iam_role.ecs_task_role.arn}",
                "cpu": ${var.frontend_ecs_config[1]},
                "memory": "${var.frontend_ecs_config[2]}",
                "runtimePlatform": {
                  "cpuArchitecture": ${var.enable_arm64 ? "\"ARM64\"" : "\"X86_64\""},
                  "operatingSystemFamily": "LINUX"
                },
                "containerDefinitions": [
                  {
                    "name": "${var.name[0]}-frontend-frontend",
                    "image": "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name[0]}-frontend:$${CODEBUILD_BUILD_NUMBER}",
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
            - echo "updating task definition..."
            - aws ecs register-task-definition --region ${var.region} --cli-input-json ${var.include_external_taskdefinition_file[1] ? "file://${var.external_taskdefinition_file[1]}" : "file://taskdef.json"} --query 'taskDefinition.taskDefinitionArn' --output text
            - REVISION=$(aws ecs describe-task-definition --task-definition ${var.name[0]}-frontend --query 'taskDefinition.revision')
            - echo 'Stopping current running tasks..'
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --desired-count 0
            - aws ecs update-service --region ${var.region} --cluster $${ecsCluster} --service $${ecsService} --deployment-configuration maximumPercent=100,minimumHealthyPercent=0
            - aws ecs update-service --region ${var.region} --service $${ecsService} --cluster $${ecsCluster} --task-definition ${var.name[0]}-frontend:$REVISION --force-new-deployment --desired-count 1                      

  EOF

}