terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module  "vpc" {
  source  = "../../modules/vpc"

  vpc_name = "manisha-dev-vpc"
  vpc_cidr = "10.0.0.0/16"
  public_subnets_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  environment = "dev"
}

module "ec2" {
  source = "../../modules/ec2"

  instance_name = "manisha-web-server"
  instance_type = "t3.micro"
  vpc_id = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets_ids[0]
  environment = "dev"
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = module.ec2.aws_instance_public_ip
}