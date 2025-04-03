module "nat-instance" {
    source = "RaJiska/fck-nat/aws"
    
    name = "nat-instance"
    vpc_id = aws_vpc.main_vpc.id
    subnet_id = aws_subnet.public_subnet_1.id
    instance_type = "t2.micro"

    use_cloudwatch_agent = true
    update_route_tables = true
    route_tables_ids = {
        "nat-route-table" = aws_route_table.private.id
    }
}

resource "aws_security_group" "nat_sg" {
    name = "nat-instance-sg"
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = [aws_vpc.main_vpc.cidr_block]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}