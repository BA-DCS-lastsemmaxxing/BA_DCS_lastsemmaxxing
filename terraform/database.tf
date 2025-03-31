locals {
    credentials = jsondecode(data.aws_ssm_parameter.db_credentials.value)
}

resource "aws_db_instance" "rds" {
    identifier = "${var.project_name}-rds"
    allocated_storage = 20
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    db_name = "lsm_fyp"
    username = local.credentials.username
    password = local.credentials.password
    publicly_accessible = false
    skip_final_snapshot = true

    vpc_security_group_ids = [aws_security_group.rds_sg.id]
    db_subnet_group_name = aws_db_subnet_group.lsm-fyp-db-subnet-group.name

    tags = {
        Name = "lsm-fyp-rds"
    }

    # depends_on = [ data.aws_vpc.default, data.aws_subnets.default ]
}

resource "aws_vpc" "private_vpc" {
    cidr_block = "172.28.0.0/16"
}

resource "aws_subnet" "private_subnet_1" {
    vpc_id = aws_vpc.private_vpc.id
    cidr_block = "172.28.1.0/24"
    availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_subnet_2" {
    vpc_id = aws_vpc.private_vpc.id
    cidr_block = "172.28.2.0/24"
    availability_zone = "ap-southeast-1b"
}

# Create a DB subnet group using the default VPC subnets
resource "aws_db_subnet_group" "lsm-fyp-db-subnet-group" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1, aws_subnet.private_subnet_2]

  tags = {
    Name = "DB Subnet Group"
  }
}

resource "aws_security_group" "rds_sg" {
    name = "${var.project_name}-rds-sg"
    vpc_id = data.aws_vpc.default.id

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["172.28.0.0/16"] 
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "RDS Security Group"
    }
}

resource "aws_security_group_rule" "rds_ingress_from_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}
