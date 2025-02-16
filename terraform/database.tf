resource "aws_db_instance" "rds" {
    allocated_storage = 20
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    db_name = "admin"
    password = "testpassword"
    publicly_accessible = true
    skip_final_snapshot = true

    vpc_security_group_ids = [aws_security_group.rds_sg.id]
    db_subnet_group_name = aws_db_subnet_group.default.name

    tags = {
        Name = "lsm-fyp-rds"
    }
}

# Fetch the default VPC
data "aws_vpc" "default" {
    default = true
}

# Fetch the default subnet in the default VPC
data "aws_subnet" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

# Create a DB subnet group using the default VPC subnets
resource "aws_db_subnet_group" "default" {
  name       = "default-subnet-group"
  subnet_ids = [data.aws_subnet.default.id]

  tags = {
    Name = "Default DB Subnet Group"
  }
}

resource "aws_security_group" "rds_sg" {
    vpc_id = aws_vpc.default.id

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # TODO: restrict to specific IP range for prod
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
