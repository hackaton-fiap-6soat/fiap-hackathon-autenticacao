terraform {
  backend "s3" {
    bucket = "fiap-hackathon-authentication-artifacts"
    region = "us-east-1"
    key = "fiap.hackathon.authentication.infra.tfstate"
  }
}

provider "aws" {
    region = "us-east-1"
}

data "aws_iam_role" LabRole {
  name = "LabRole"
}