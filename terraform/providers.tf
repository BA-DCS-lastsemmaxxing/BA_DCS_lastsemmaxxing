terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.90.0"
    }
  }
}

provider "aws" {
  region = var.region
}

output "aws_region" {
  value = var.region
}

# for our lambda@edge assets to use with cloudfront
provider "aws" {
    alias = "us_east_1"
    region = "us-east-1"
}
