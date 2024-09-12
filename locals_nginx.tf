# Nginx configuration buildspec.yml scripts

locals {

  #########################################################################################################
  # BACKEND
  #########################################################################################################
  # 1
  ## Nginx: used when config file source is not used, and writing config file directly from pipeline.
  buildspec_not_version_controlled = <<EOF
# This will build Nginx image with configuration file
version: 0.2
phases:
  pre_build:
    commands:
      # Log in ECR registry
      - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

  build:
    commands:
      # Writing Local Nginx Configuration File
      - echo 'Writing Local Nginx Configuration File'
      - |
        cat << 'END' > ./default.conf
        server {
          listen 80;
          server_name _;
          location / {
            proxy_pass http://localhost:${var.backend_ecs_config[0]};
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
          }
        }
        END
      
      # Writing Local Dockerfile
      - echo 'Writing Local ./Dockerfile'
      - |
        cat << 'END' > Dockerfile
        FROM public.ecr.aws/nginx/nginx:stable-perl
        COPY ./default.conf /etc/nginx/conf.d/
        END

      # Building Nginx Image
      - echo 'Building Nginx Image'
      - docker build -t nginx .

  post_build:
    commands:
      # Pushing image to repository
      - echo 'Pushing Image to ECR repository'
      - docker tag nginx:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}
      - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}

  EOF



  # 2
  ## Nginx: used when nginx config file source is used.
  buildspec_version_controlled = <<EOF
# This will build Nginx image with configuration file
version: 0.2
phases:
  pre_build:
    commands:
      # Log in ECR registry
      - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

  build:
    commands:
      # Writing Local Dockerfile
      - echo 'Writing Local ./Dockerfile'
      - |
        cat << 'END' > Dockerfile
        FROM public.ecr.aws/nginx/nginx:stable-perl
        COPY ./${var.nginx_config_file[1]} /etc/nginx/conf.d/
        END

      # Building Nginx Image
      - echo 'Building Nginx Image'
      - docker build -t nginx .

  post_build:
    commands:
      # Pushing image to repository
      - echo 'Pushing Image to ECR repository'
      - docker tag nginx:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}
      - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}
  EOF



  ##########################################################################################################
  # FRONTEND
  ##########################################################################################################
  # 1
  ## Nginx: used when there is no config file source.
  frontend_buildspec_not_version_controlled = <<EOF
# This will build Nginx image with configuration file
version: 0.2
phases:
  pre_build:
    commands:
      # Log in ECR registry
      - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

  build:
    commands:
      # Writing Local Nginx Configuration File
      - echo 'Writing Local Nginx Configuration File'
      - |
        cat << 'END' > ./default.conf
        server {
          listen 80;
          server_name _;
          location / {
            proxy_pass http://localhost:${var.frontend_ecs_config[0]};
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
          }
        }
        END
      
      # Writing Local Dockerfile
      - echo 'Writing Local ./Dockerfile'
      - |
        cat << 'END' > Dockerfile
        FROM public.ecr.aws/nginx/nginx:stable-perl
        COPY ./default.conf /etc/nginx/conf.d/
        END

      # Building Nginx Image
      - echo 'Building Nginx Image'
      - docker build -t nginx .

  post_build:
    commands:
      # Pushing image to repository
      - echo 'Pushing Image to ECR repository'
      - docker tag nginx:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend
      - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend

  EOF



  # 2
  ## Nginx: used when there is config file source.
  frontend_buildspec_version_controlled = <<EOF
# This will build Nginx image with configuration file
version: 0.2
phases:
  pre_build:
    commands:
      # Log in ECR registry
      - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com

  build:
    commands:
      # Writing Local Dockerfile
      - echo 'Writing Local ./Dockerfile'
      - |
        cat << 'END' > Dockerfile
        FROM public.ecr.aws/nginx/nginx:stable-perl
        COPY ./${var.frontend_nginx_config_file[1]} /etc/nginx/conf.d/
        END

      # Building Nginx Image
      - echo 'Building Nginx Image'
      - docker build -t nginx .

  post_build:
    commands:
      # Pushing image to repository
      - echo 'Pushing Image to ECR repository'
      - docker tag nginx:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend
      - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/nginx:${var.name[0]}-frontend
  EOF

}