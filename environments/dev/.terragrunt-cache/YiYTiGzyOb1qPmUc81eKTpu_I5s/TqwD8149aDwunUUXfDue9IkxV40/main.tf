terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    enable_dns_support   = true
    enable_dns_hostnames = true

    tags = {
        Name        = var.vpc_name
        Environment = var.environment
    }
}

resource "aws_default_security_group" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name        = "${var.vpc_name}-default-sg-restricted    "
        Environment = var.environment
    }   
}


resource "aws_flow_log" "main" {
    vpc_id              = aws_vpc.main.id
    traffic_type        = "ALL"
    iam_role_arn        = aws_iam_role.flow_log_role.arn
    log_destination     = aws_cloudwatch_log_group.flow_logs.arn
}

#checkov:skip=CKV2_AWS_64:Using default KMS key policy which grants access to account root
resource "aws_kms_key" "flow_log" {
    description             = "KMS key for VPC flow logs"
    deletion_window_in_days = 7
    enable_key_rotation     = true

    tags = {
        Name        = "${var.vpc_name}-flow-log-key"
        Environment = var.environment
    }
}


resource "aws_cloudwatch_log_group" "flow_logs" {
    name = "/aws/vpc/flow-logs/${var.vpc_name}"
    retention_in_days = 365
    kms_key_id = aws_kms_key.flow_log.arn
    }

resource "aws_iam_role" "flow_log_role" {
    name = "${var.vpc_name}-flow-log-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "vpc-flow-logs.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy" "flow_log" {
    name   = "${var.vpc_name}-flow-log-policy"
    role   = aws_iam_role.flow_log_role.id
    #tfsec:ignore:aws-iam-no-policy-wildcards
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams"
                ]
                Resource = [
                    "aws_cloudwatch_log_group.flow_logs.arn",
                    "${aws_cloudwatch_log_group.flow_logs.arn}:*"
                ]
            }
        ]
    })
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name        = "${var.vpc_name}-igw"
        Environment = var.environment
    }
}

resource "aws_subnet" "public" {
    count             = length(var.public_subnets_cidrs)
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.public_subnets_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]
    #tfsec:ignore:aws-ec2-no-public-ip-subnet
    #checkov:skip=CKV_AWS_130:Public subnets intentionally assign public IPs
    map_public_ip_on_launch = true

    tags = {
        Name        = "${var.vpc_name}-public-${count.index + 1}"
        Environment = var.environment
    }
}

resource "aws_subnet" "private" {
    count             = length(var.private_subnets_cidrs)
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.private_subnets_cidrs[count.index]
    availability_zone = var.availability_zones[count.index]

    tags = {
        Name        = "${var.vpc_name}-private-${count.index + 1}"
        Environment = var.environment
        type        = "private"
    }
}

resource "aws_eip"  "nat" {
    domain = "vpc"

    tags = {
        Name        = "${var.vpc_name}-nat-eip"
        Environment = var.environment
    }
}

resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id     = aws_subnet.public[0].id

    tags = {
        Name        = "${var.vpc_name}-nat"
        Environment = var.environment
    }

    depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.main.id
    }

    tags = {
        Name        = "${var.vpc_name}-public-rt"
        Environment = var.environment
    }
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block     = "0.0.0.0/0"
        gateway_id     = aws_nat_gateway.main.id
    }

    tags = {
        Name        = "${var.vpc_name}-private-rt"
        Environment = var.environment
    }
}

resource "aws_route_table_association" "public" {
    count          = length(var.public_subnets_cidrs)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    count          = length(var.private_subnets_cidrs)
    subnet_id      = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id
}
