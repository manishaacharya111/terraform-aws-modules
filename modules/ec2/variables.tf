variable "instance_name" {
    description = "The type of instance to start"
    type        = string
    }

variable "instance_type" {
    description = "The type of the instance"
    type        = string
    default     = "t2.micro"
    }

variable "subnet_id" {
    description = "VPC ID for the security group"
    type        = string
    }

variable "vpc_id" {
    description = "VPC ID for the security group"
    type        = string
    }

variable "environment" {
    description = "Environment name"
    type        = string
    default     = "dev"
    }

variable "key_name" {
    description = "EC2 key pair name for SSH access"
    type        = string
    default     = null
    }
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed SSH access. Use VPN CIDR or bastion SG in production. Never 0.0.0.0/0."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}
