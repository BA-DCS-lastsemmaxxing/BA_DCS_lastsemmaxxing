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

# Create a DB subnet group using the default VPC subnets
resource "aws_db_subnet_group" "lsm-fyp-db-subnet-group" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "DB Subnet Group"
  }
}
