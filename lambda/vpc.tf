data "aws_vpc" "hackathon-vpc" {
  filter {
    name   = "tag:Name"
    values = ["hackathon-vpc"]
  }
}

data "aws_subnets" "private-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.hackathon-vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Security group for Lambda"
  vpc_id      = data.aws_vpc.hackathon-vpc.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = [data.aws_vpc.hackathon-vpc.cidr_block]
  }
}