resource "aws_vpc" "private_vpc" {
  cidr_block = "172.28.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Private VPC"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.private_vpc.id
  cidr_block        = "172.28.1.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.private_vpc.id
  cidr_block        = "172.28.2.0/24"
  availability_zone = "ap-southeast-1b"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.private_vpc.id

  route {
    cidr_block                = "172.20.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.bedrock_peering.id
  }
}

# VPC Endpoint for rds_init lambda to access S3
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.private_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "S3 VPC Endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_association" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
}

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint_policy" "s3_endpoint_policy" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_security_group" "rds_sg" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.private_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["172.28.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# VPC Endpoint for step_function trigger lambda to reach step function
resource "aws_vpc_endpoint" "step_function_endpoint" {
  vpc_id            = aws_vpc.private_vpc.id
  service_name      = "com.amazonaws.${var.region}.states"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids  = [aws_security_group.step_function_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "Step Function VPC Endpoint"
  }
}

resource "aws_security_group" "step_function_sg" {
  name   = "${var.project_name}-step-function-sg"
  vpc_id = aws_vpc.private_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.28.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Step Functions Security Group"
  }
}

# VPC and VPC endpoint for bedrock
resource "aws_vpc" "bedrock_vpc" {
  provider             = aws.us_west_2
  cidr_block           = "172.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "us-west-2 Bedrock VPC"
  }
}

resource "aws_subnet" "bedrock_subnet" {
  provider          = aws.us_west_2
  vpc_id            = aws_vpc.bedrock_vpc.id
  cidr_block        = "172.20.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "bedrock-subnet"
  }
}

resource "aws_route_table" "bedrock_rt" {
  provider = aws.us_west_2
  vpc_id   = aws_vpc.bedrock_vpc.id

  route {
    cidr_block                = "172.28.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.bedrock_peering.id
  }

  tags = {
    Name = "bedrock-route-table"
  }
}

resource "aws_route_table_association" "bedrock_subnet_association" {
  provider       = aws.us_west_2
  subnet_id      = aws_subnet.bedrock_subnet.id
  route_table_id = aws_route_table.bedrock_rt.id
}

resource "aws_vpc_endpoint" "bedrock_endpoint" {
  provider          = aws.us_west_2
  vpc_id            = aws_vpc.bedrock_vpc.id
  service_name      = "com.amazonaws.us-west-2.bedrock-runtime"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.bedrock_subnet.id
  ]
  security_group_ids = [aws_security_group.bedrock_sg.id]

  tags = {
    Name = "Bedrock VPC Endpoint"
  }
}

resource "aws_vpc_peering_connection" "bedrock_peering" {
  vpc_id      = aws_vpc.private_vpc.id
  peer_vpc_id = aws_vpc.bedrock_vpc.id
  peer_region = "us-west-2"

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Name = "Bedrock VPC Peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "peer_accept" {
  provider                  = aws.us_west_2
  vpc_peering_connection_id = aws_vpc_peering_connection.bedrock_peering.id
  tags = {
    Name = "Bedrock VPC Peering Accepter"
  }
}

resource "aws_security_group" "bedrock_sg" {
  provider = aws.us_west_2
  name     = "${var.project_name}-bedrock-sg"
  vpc_id   = aws_vpc.bedrock_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.28.0.0/16"] # Allow Lambda to reach Bedrock from ap-southeast-1
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bedrock Security Group"
  }
}

# VPC endpoint for SQS
resource "aws_vpc_endpoint" "sqs_endpoint" {
  vpc_id            = aws_vpc.private_vpc.id
  service_name      = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids  = [aws_security_group.sqs_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "SQS VPC Endpoint"
  }
}

resource "aws_security_group" "sqs_sg" {
  name   = "${var.project_name}-sqs-sg"
  vpc_id = aws_vpc.private_vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id] # Allow Lambda to reach SQS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SQS Security Group"
  }
}
