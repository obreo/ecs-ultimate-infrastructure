# VPC
# Doc: https://registry.terraform.io/providers/hashicorp/aws/3.74.3/docs/resources/vpc

resource "aws_vpc" "vpc" {
  count                = var.include_vpc[0] == "true" ? 1 : 0
  cidr_block           = "10.2.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name[0]
  }
}

# EC2 Subnet - Primary - Backend/Frontend
resource "aws_subnet" "subnet_a" {
  count                   = var.include_vpc[0] == "true" ? 1 : 0
  vpc_id                  = aws_vpc.vpc[count.index].id
  cidr_block              = "10.2.0.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name[0]}-subnet-a"
    Purpose = "Cluster"
  }
}

# EC2 Subnet - Primary - Backend/Frontend
resource "aws_subnet" "subnet_b" {
  count                   = var.include_vpc[0] == "true" ? 1 : 0
  vpc_id                  = aws_vpc.vpc[count.index].id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name[0]}-subnet-b"
    Purpose = "Cluster"

  }
}

# RDS Subnet - Primary
resource "aws_subnet" "subnet_c" {
  count                   = var.include_vpc[0] == "true" && var.include_rds == true ? 1 : 0
  vpc_id                  = aws_vpc.vpc[0].id
  cidr_block              = "10.2.3.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name[0]}-subnet-c"
    Purpose = "Database"
  }
}

# RDS Subnet - Secondary
resource "aws_subnet" "subnet_d" {
  count                   = var.include_vpc[0] == "true" && var.include_rds == true ? 1 : 0
  vpc_id                  = aws_vpc.vpc[0].id
  cidr_block              = "10.2.4.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name[0]}-subnet-d"
    Purpose = "Database"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gate_w" {
  count  = var.include_vpc[0] == "true" ? 1 : 0
  vpc_id = aws_vpc.vpc[count.index].id

  tags = {
    Name = "${var.name[0]}-gateway"
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}


# Route table
# Routing all subnet to the internet / and later restricting access using ACLs
resource "aws_route_table" "route-table" {
  count  = var.include_vpc[0] == "true" ? 1 : 0
  vpc_id = aws_vpc.vpc[count.index].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gate_w[count.index].id
  }

  tags = {
    Name = "${var.name[0]}"
  }
}
# Frontend / Backend
resource "aws_route_table_association" "subnet_a" {
  count          = var.include_vpc[0] == "true" ? 1 : 0
  subnet_id      = aws_subnet.subnet_a[count.index].id
  route_table_id = aws_route_table.route-table[count.index].id
}
resource "aws_route_table_association" "subnet_b" {
  count          = var.include_vpc[0] == "true" ? 1 : 0
  subnet_id      = aws_subnet.subnet_b[count.index].id
  route_table_id = aws_route_table.route-table[count.index].id
}
# Database
resource "aws_route_table_association" "subnet_c" {
  count          = var.include_vpc[0] == "true" ? 1 : 0
  subnet_id      = aws_subnet.subnet_c[count.index].id
  route_table_id = aws_route_table.route-table[count.index].id
}
resource "aws_route_table_association" "subnet_d" {
  count          = var.include_vpc[0] == "true"  ? 1 : 0
  subnet_id      = aws_subnet.subnet_d[count.index].id
  route_table_id = aws_route_table.route-table[count.index].id
}


# Security Groups
#Instances - Allowing ports 80 & 443
resource "aws_security_group" "application_sg" {
  count       = var.include_vpc[0] == "true" ? 1 : 0
  name        = "${var.name[0]}-application"
  description = "Allows web access"
  vpc_id      = aws_vpc.vpc[count.index].id

  tags = {
    Application = "${var.name[0]}"
    Purpose     = "web access"
  }
}
# Inbound
resource "aws_security_group_rule" "application_sg_https" {
  for_each          = toset(var.accessable_application_ports)
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  type              = "ingress"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.application_sg[0].id
}
# Outbound
resource "aws_vpc_security_group_egress_rule" "instacne_allow_all_egress" {
  count             = var.include_vpc[0] == "true" ? 1 : 0
  security_group_id = aws_security_group.application_sg[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Database security group
resource "aws_security_group" "rds" {
  count       = var.include_rds == true ? 1 : 0
  name        = "${var.name[0]}-database"
  description = "Allow access"
  vpc_id      = aws_vpc.vpc[count.index].id

  tags = {
    Name  = "${var.name[0]}-datebase"
    Ports = "${var.database_port}"
  }
}
# Ingress
resource "aws_vpc_security_group_ingress_rule" "allow_database" {
  count             = var.include_vpc[0] == "true" && var.include_rds == true ? 1 : 0
  security_group_id = aws_security_group.rds[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.database_port
  ip_protocol       = "tcp"
  to_port           = var.database_port
}
# Outgress
resource "aws_vpc_security_group_egress_rule" "allow_database_egress" {
  count             = var.include_rds == true ? 1 : 0
  security_group_id = aws_security_group.rds[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# ACLs
resource "aws_network_acl" "acl_database" {
  count      = var.include_vpc[0] == "true" && var.include_rds == true && var.allow_acl[0] == "true" ? 1 : 0
  vpc_id     = aws_vpc.vpc[count.index].id
  subnet_ids = [aws_subnet.subnet_c[count.index].id, aws_subnet.subnet_d[count.index].id]

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = var.allow_acl[1]
    from_port  = var.database_port
    to_port    = var.database_port
  }

  tags = {
    Application = "${var.name[0]}"
  }
}


# Security Group - Application Load Balancer
#Instances - Allowing ports 80 & 443
resource "aws_security_group" "load_balancer" {
  count       = var.include_vpc[0] == "true" && var.disable_autoscaling[0] == "false" ? 1 : 0
  name        = "${var.name[0]}-alb-sg"
  description = "Allow web access through application load balancer"
  vpc_id      = aws_vpc.vpc[count.index].id

  tags = {
    Name  = "${var.name[0]}-alb-sg"
    Ports = "80/443"
  }
}
# Ingress
resource "aws_vpc_security_group_ingress_rule" "loadbalancer_allow_http" {
  count             = var.include_vpc[0] == "true" && var.disable_autoscaling[0] == "false" ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "loadbalancer_allow_https" {
  count             = var.include_vpc[0] == "true" && var.disable_autoscaling[0] == "false" ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
# Outgress
resource "aws_vpc_security_group_egress_rule" "loadbalance_allow_all_egress" {
  count             = var.include_vpc[0] == "true" && var.disable_autoscaling[0] == "false" ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Keypair
resource "aws_key_pair" "deployer" {
  count      = var.include_ssh_key[0] == "true" ? 1 : 0
  key_name   = var.name[0]
  public_key = var.include_ssh_key[1]
}