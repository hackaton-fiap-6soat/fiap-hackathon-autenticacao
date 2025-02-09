terraform {
  backend "s3" {
    bucket = ""
    key = ""
    region = ""
  }
}

provider "aws" {
    region = "us-east-1"
}

data "aws_iam_role" LabRole {
  name = "LabRole"
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}