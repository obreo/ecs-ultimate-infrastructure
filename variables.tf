# variables
# Profile
variable "account_id" {
  description = "AWS Account ID"
  type        = string
  #sensitive   = true
  default = ""
}
variable "region" {
  description = "AWS region"
  type        = string
  default     = ""
}

# General
variable "name" {
  description = "Application's name & Envriornment [Name,Envrionment]"
  type        = list(string)
  default     = ["", ""] # [Name,Envrionment]
}
variable "fargate_cluster" {
  description = "set True if using Fargate, false if using EC2 Cluster"
  type        = bool
  default     = false
}
variable "disable_autoscaling" {
  description = "Disable Autoscaling for the application: if truned on, Add a custom load balancer ARN - CodeDeploy and Application load balancer will not be created"
  type        = list(string)
  default = [
    "false", # [0]
    "",      # [1]ALB ARN
    "",      # [2]Listener ARN
    "",      # [3]Backend / Primary Target group Name - blue
    "",      # [4]Backend / Primary Target Group Name- green
    "",      # [5]Frontend Target Group Name- blue
    ""       # [6]Frontend Target Group Name- blue
  ]
}


# Frontend - Optional
variable "include_frontend_bucket" {
  description = "Setup S3 bucket for the Frontend - suitable for static site application | CONFLICT WITH ECS FRONTEND"
  type        = bool
  default     = false
}
variable "include_frontend_ecs_service" {
  description = "Setup ECS service for the Frontend - suitable for applications that require server side rendering (SSR) | CONFLICT WITH S3 FRONTEND"
  type        = bool
  default     = true
}


# SSM Parameter Store - Optional
variable "include_ssm_parameter_resource" {
  description = "Create terraform ssm paramters resources ['ssm_parameters_path_backend' , 'ssm_parameters_path_frontend']"
  type        = list(bool)
  default     = [false, false]
}
variable "ssm_parameters_path" {
  description = "set the parameter store path for the application environment variables ['ssm_parameters_path_backend' , 'ssm_parameters_path_frontend']"
  type        = list(string)
  default     = ["", ""]
}
variable "env_path" {
  description = "Upload local environment variables (.env) file directly to s3 bucket - ['BACKEND/FILE_PATH/.env' , 'FRONTEND/FILE_PATH/.env']"
  type        = list(string)
  default     = ["", ""]
}


# CICD - optional
variable "include_codebuild" {
  description = "Setup codebuild for CI deployment for ECS. Set to False if a third party CI tools is being used. | This variable with (include_frontend_ecs_service) CONFLICTs WITH (include_frontend_bucket)"
  type        = bool
  default     = true
}
variable "include_codebuild_for_s3" {
  description = "Setup codebuild for CI step for S3 frontend bucket | CONFLICT WITH (include_frontend_ecs_service=true)"
  type        = bool
  default     = false
}
variable "frontend_resposiotry_id" {
  description = "for Codepipeline. Respository where the source code resides and the branch name ['ORG/REPOSITRY', 'BRANCH'] | SKIP IF USING PUBLIC CONTINAER IMAGE"
  type        = list(string)
  default     = ["", ""] # ['ORG/REPOSITRY', 'BRANCH']
}
variable "backend_resposiotry_id" {
  description = "for Codepipeline. Respository where the source code resides and the branch name ['ORG/REPOSITRY', 'BRANCH'] | SKIP IF USING PUBLIC CONTINAER IMAGE"
  type        = list(string)
  # OPTIONAL
  default = ["", ""] # ['ORG/REPOSITRY', 'BRANCH']
}
variable "include_external_taskdefinition_file" {
  description = "Enabling this will overwrite the taskdefinition used by CodeBuild with a custom task-definition.json file clonned from git repository. ENABLING THIS REQUIRES MODIFYING the default ECS-TASK-DEFINITION TERRAFORM RESOURCE USING 'local_custom_initial_taskdefinition.tf' file', Otherwise CICD will not work."
  type        = list(bool)
  default     = [false, false] # [BACKEND, FRONTEND]
}
variable "external_taskdefinition_file" {
  description = "Name of custom task-definition.json file that that will be used in the codebuild artifacts - related to `include_external_taskdefinition_file` variable"
  type        = list(string)
  default     = ["", ""] # [BACKEND, FRONTEND]
}

# Nginx: 
# Optional
variable "enable_nginx" {
  description = "Enable Nginx for backend/frontend. if disabled, task definition will use the application image only, service load balancer will use image port"
  type        = list(bool)
  default     = [true, true] # [BACKEND , FRONTEND]
}
# Required if enable_nginx=true
variable "build_nginx_application" {
  description = "Setup ECR registry & codebuild for Nginx image as a proxy server [true/false) | Insert Nginx image uri - If already exists and (build_nginx_application=false). [true/false , 'NGINX_URI', 'NGINX_URI_FRONTEND']"
  type        = list(string)
  default     = ["true", "nginx:latest", "nginx:latest"] # [true/false , "NGINX_URI", "NGINX_URI_FRONTEND"] 
}
# Optional if build_nginx_application=true
variable "write_nginx_config" {
  description = "Codebuild will write an nginx config file before creating the ECR image. Codebuild will use nginx configuration file from repository if set to False."
  type        = bool
  default     = true
}
variable "trigger_nginx" {
  description = "Runs local executive command to let codebuild create and push Nginx image using aws cli | Works if write_nginx_config=true"
  type        = list(bool)
  default     = [true, true] # [BACKEND , FRONTEND]
}
# Required if build_nginx_application=false & enable_nginx=true
variable "nginx_config_file" {
  description = "Branch & file where nginx config file exists - Used when (write_nginx_config=false). ['BRANCH','FILE_NAME']"
  type        = list(string)
  default     = ["", ""] # ['BRANCH','FILE_NAME']
}
# Required if build_nginx_application=false & enable_nginx=true
variable "frontend_nginx_config_file" {
  description = "Branch & file where nginx config file exists - Used when (write_nginx_config=false) ['BRANCH','FILE_NAME']"
  type        = list(string)
  default     = ["", ""] # ['BRANCH','FILE_NAME']
}


# RESOURCE SETTINGS
# Load balancer - Depends on [Disable_loadbalancer] | "force_HTTPS" Optional but recommended if ECS frontend created.
variable "force_HTTPS" {
  description = "Enables HTTPS listener instead of HTTP [true/false, 'ACM_TLS_CERTIFICATE_ARN']"
  type        = list(string)
  default     = ["false", ""] # [true/false, 'TLS_CERTIFICATE_ARN' (if true)]
}

# Route53 - Required if "Frontend ECS" is included
variable "domain" {
  description = "Application domain 'example.TLD'. This will be used for shared load balacner hsotnames for both tiers - backend.example.com(backend) & example.com/www.example.com(frontend)"
  type        = string
  default     = "" # example: xyz.com
}
variable "zone_id" {
  description = "Route53 host zone that will be used to route Alias records to application load balancer for frontend and backend tiers - only works if frontend tier included."
  type        = string
  default     = ""
}

# VPC
variable "include_vpc" {
  description = "Create VPC for the infrastrucure. If set to False, Include VPC, Subnets, and Security Groups IDs."
  type        = list(string)
  default = [
    "true", # [0]List should be filled if set to FALSE.
    "",     # [1]VPC ID
    "",     # [2]Subnet-a - Backend / Frontend tier
    "",     # [3]Subnet-b - Backend / Frontend tier
    "",     # [4]Subnet-c - Database (Required if Database included)
    "",     # [5]Subnet-d - Database (Required if Database included)
    "",     # [6]Cluster Security Group
    "",     # [7]Load Balancer Security Group
    "",     # [8]RDS Security group
    "",     # [9]SSH_KeyPairName
  ]
}
variable "accessable_application_ports" {
  description = "List of inbound ports to allow in the security group for the application server"
  type        = list(string)
  default     = ["80", "443", "22"] # Example default ports (HTTP, HTTPS, etc...)
}
variable "include_ssh_key" {
  description = "Build Key to Allow SSH Access to Application"
  type        = list(string)
  default     = ["false", ""] # ["true/false" , "SSH Public Key" (if true)]
}


# ECS - Required
# Doc: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
variable "backend_ecs_config" {
  description = "[APPLICATION_PORT, Task vCPU capacity required - in MB, Task Memroy capacity required - in MB]"
  type        = list(number)
  default     = [0, 256, 512] #[PORT,vCPU,MEMORY]
}
variable "frontend_ecs_config" {
  description = "[APPLICATION_PORT, Task vCPU capacity required - in MB, Task Memroy capacity required - in MB]"
  type        = list(number)
  default     = [80, 256, 512] #[PORT,vCPU,MEMORY]
}
variable "enable_service_connect" {
  description = "This allows service connect for the backend and frontend. If Enabled, codedeploy will be disabled."
  type        = bool
  default     = false
}
variable "enable_arm64" {
  description = "Use ARM64 architechture."
  type        = bool
  default     = false
}
variable "ecs_ec2_type" {
  description = "EC2 Type"
  type        = string
  default     = "t3.small"
}
variable "use_port_80_in_nonnginx_taskdef" {
  description = "As this infrastructure uses Appliaction load balancer, this variable is used in the initial creation of ecs services of frontend apps which use port 80, to avoid ecs service failure due to non nginx task definition image ports. Allowing this variable will let using the default frontend image port - in case of willing to use Network load balancer - otherwise it will use port 80."
  type        = bool
  default     = true # [True(enable port 80 for single images without ngnix) /False (use custom port assigned to image - could fail service creation if load balancer is ALB)]
}

# Storage - Enabled within CICD deployment ONLY.
variable "include_efs_ebs_bind" {
  description = "Include volume storage - choose one: [EFS, EBS (supports EC2), Bind, Ephemeral (supports Fargate)]"
  type        = list(string)
  default     = ["false", "false", "false", "false"] #[true/false]
}
variable "storage_details" {
  description = "Ephemeral/EBS volume size, EBS & Bind mount details - Related to include_efs_ebs_bind. [Size_in_GB (>21GB), ContainerPath, HostPath - for both Bind / EBS]"
  type        = list(string)
  default     = ["21", "", ""]
}
variable "efs_details" {
  description = "EFS volume details - Related to include_efs_ebs_bind. [fileSystemId , ContainerPath]"
  type        = list(string)
  default     = ["", ""]
}

# S3 - Required
variable "artifacts_bucket" {
  description = "Specify the artifacts bucket to be used for secrets [true / false, 'Artifact Bucket Name' (if set to False)]"
  type        = list(string)
  default     = ["true", ""]
}

# ECR - Optional
variable "include_application_registry" {
  description = "Setup ECR registry for backend/primary Application. Insert image uri if Already exist and include_application_registry is set to False. [True/False, 'IMAGE_URI']"
  type        = list(string)
  default     = ["true", ""] # [True/False, 'IMAGE_URI' (if False)]
}
variable "include_frontend_application_registry" {
  description = "Setup ECR registry for the frontend Application - works if include_frontend_ecs_service is set to True. | Insert frontend Application image uri - If Already exist and include_frontend_application_registry is set to False."
  type        = list(string)
  default     = ["true", ""] # [True/False, 'IMAGE_URI' (if False)]
}



#RDS - optional
variable "include_rds" {
  description = "Include RDS in the infrastructure"
  type        = bool
  default     = true
}
variable "username" {
  description = "RDS - database username"
  type        = string
  sensitive   = false
  default     = ""
}
variable "password" {
  description = "RDS - database password - minimum 8 characters"
  type        = string
  sensitive   = false
  default     = ""
}
variable "database_port" {
  description = "RDS - database port"
  type        = number
  default     = 3306
}
variable "allow_acl" {
  description = "Set ACL restriction for the RDS subnet. Add CIDR Range If Set to TRUE- [true/false, 'CIDR_IP']"
  type        = list(string)
  default     = ["false", "0.0.0.0/0"] # [true/false, 'CIDR_IP' (if true) - Depends on "include_rds"] 
}
