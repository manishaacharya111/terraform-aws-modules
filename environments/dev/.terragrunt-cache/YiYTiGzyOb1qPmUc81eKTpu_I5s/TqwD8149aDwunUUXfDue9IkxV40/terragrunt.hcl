include "root"{
    path = find_in_parent_folders("root.hcl")
}

terraform {
    source = "../../modules/vpc"
}

inputs = {
    vpc_name = "manisha-dev-vpc"
    vpc_cidr = "10.0.0.0/16"
    public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
    availability_zones = ["eu-west-1a", "eu-west-1b"]
    environment = "dev"
}