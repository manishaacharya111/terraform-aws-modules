variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "vpc_cidr" {
    description = "The CIDR block for the VPC."
    type        = string
    default     = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
    description = "A list of CIDR blocks for the public subnets."
    type        = list(string)
    default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidrs" {
    description = "A list of CIDR blocks for the private subnets."
    type        = list(string)
    default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
    description = "List of availability zones to deploy subnets into"
    type        = list(string)
    default     = ["eu-west-1a", "eu-west-1b"]
}

variable "environment" {
    description = "The environment name  dev, staging, prod"
    type        = string
    default     = "dev"
}

variable "allowed_cidr_blocks" {
    description = "A list of CIDR blocks that are allowed to access the VPC."
    type        = list(string)
    default     = ["10.0.0.0/8"]
}   
