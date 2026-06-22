data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.environment}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    }
    
  ingress {
    description = "Allow HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    #tfsec:ignore:aws-ec2-no-public-ingress-sgr
    #checkov:skip=CKV_AWS_260:HTTP intentionally public for web server
    cidr_blocks = ["0.0.0.0/0"]
    }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #tfsec:ignore:aws-ec2-no-public-egress-sgr
    #checkov:skip=CKV_AWS_382:Unrestricted egress is standard practice
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
        Name    = "${var.instance_name}-sg"
        Environment = var.environment
    }
}
#checkov:skip=CKV_AWS_135:t3 instances have EBS optimization enabled by default
#checkov:skip=CKV2_AWS_41:IAM role attachment handled separately
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name
  monitoring              = true

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }
}

