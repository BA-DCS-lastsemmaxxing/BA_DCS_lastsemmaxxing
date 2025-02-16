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

    tags = {
        Name = "lsm-fyp-rds"
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
