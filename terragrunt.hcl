locals {
    aws_region = "us-east-1"
}

remote_state {
    backend = "s3"
    config = {
        bucket         = "manisha-terraform-state-${local.aws_region}"
        key            = "${path_relative_to_include()}/terraform.tfstate"
        region         = local.aws_region
        encrypt        = true
        use_lockfile   = true
    }
    generate = {
        path      = "backend.tf"
        if_exists = "overwrite_terragrunt"
    }
}

generate "provider" {
    path      = "provider.tf"
    if_exists = "overwrite_terragrunt"
    contents   = <<EOF
provider "aws" {
    region = "${local.aws_region}"
}
EOF 
}