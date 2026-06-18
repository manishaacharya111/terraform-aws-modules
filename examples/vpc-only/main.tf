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

module "vpc" {
  source = "../../modules/vpc"

  vpc_name               = "manisha-dev-vpc"
  vpc_cidr               = "10.0.0.0/16"
  public_subnets_cidrs   = ["10.0.1.0/24" , "10.0.2.0/24"]
  private_subnets_cidrs  = ["10.0.10.0/24", "10.0.20.0/24"]
  availability_zones     = ["eu-west-1a", "eu-west-1b"]
  environment            = "dev"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets_ids" {
  value = module.vpc.public_subnets_ids
}

output "private_subnets_ids" {
  value = module.vpc.private_subnets_ids
}
