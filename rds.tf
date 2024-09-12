# Doc: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide
# RDS Configuration
resource "aws_db_instance" "rds" {
  count                  = var.include_rds == true ? 1 : 0
  identifier             = var.name[0]
  allocated_storage      = 20
  db_name                = var.name[0]
  engine                 = "mysql"
  engine_version         = "8.0.37"
  instance_class         = "db.t4g.micro"
  username               = var.username
  password               = var.password
  skip_final_snapshot    = true
  vpc_security_group_ids = var.include_vpc[0] == "true" ? [aws_security_group.rds[count.index].id] : [var.include_vpc[8]]
  db_subnet_group_name   = aws_db_subnet_group.subnet_group[count.index].name
  multi_az               = false
  # To allow public access from the internet
  publicly_accessible  = true
  parameter_group_name = aws_db_parameter_group.default[count.index].name
}

# Parameter group
resource "aws_db_parameter_group" "default" {
  count  = var.include_rds == true ? 1 : 0
  name   = "mysql-custom"
  family = "mysql8.0"

  # To avoid "unable to resolve IP" error by ECS
  parameter {
    name  = "skip_name_resolve"
    value = "1"
    # To avoid  Error "cannot use immediate apply method for static parameter"
    apply_method = "pending-reboot"
  }
}


# RDS Subnet Group
## There should be minimum of two subnets in a subnet group
resource "aws_db_subnet_group" "subnet_group" {
  count      = var.include_rds == true ? 1 : 0
  name       = "${var.name[0]}-subnet-group"
  subnet_ids = var.include_vpc[0] == "true" ? [aws_subnet.subnet_c[count.index].id, aws_subnet.subnet_d[count.index].id] : [var.include_vpc[4], var.include_vpc[5]]

  tags = {
    Name = "${var.name[0]}-subnet-group"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.rds[0].endpoint
}