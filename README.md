# Terraform AWS Modules
# Terraform AWS Modules — VPC and EC2 from scratch

## What was built

Two reusable Terraform modules written from a blank file — no registry modules — composed together to provision a complete network and compute layer on real AWS.

## Modules

### VPC module (`modules/vpc`)
- Full network: VPC, 2 public subnets, 2 private subnets, Internet Gateway, NAT Gateway, route tables, route table associations
- Public subnets route to Internet Gateway; private subnets route to NAT Gateway
- Parameterised via variables — CIDR ranges, AZs, environment, vpc name
- 6 outputs exposing VPC ID, subnet IDs, gateway IDs for downstream consumption

### EC2 module (`modules/ec2`)
- Launches an EC2 instance with a dynamically-resolved latest Amazon Linux 2023 AMI (via `data` source — no hardcoded AMI IDs)
- Creates and attaches a security group (SSH + HTTP ingress, all egress)
- Designed to be composed with the VPC module — takes `vpc_id` and `subnet_id` as required inputs

### Composition example (`examples/vpc-with-ec2`)
- Calls both modules together
- EC2 module consumes VPC module's outputs directly: `subnet_id = module.vpc.public_subnet_ids[0]`
- Proves real module reusability — not just two separate modules, but one depending on the other's outputs

## Verified on real AWS
- `terraform plan` → 16 resources (14 VPC + 2 EC2)
- `terraform apply` → all resources created successfully
- EC2 instance received a real public IP, confirmed reachable on port 22
- `terraform destroy` → all 16 resources cleanly removed, zero leftover cost

## Key debugging story — map_public_ip_on_launch

After applying, the EC2 instance launched successfully into the correct public subnet (confirmed via `aws ec2 describe-instances`) but had no public IP address — `PublicIP: None`.

**Investigation:** Confirmed via AWS CLI that the instance's private IP (`10.0.1.75`) matched the public subnet's CIDR range, so subnet placement was correct. The issue wasn't routing — it was IP assignment.

**Root cause:** In AWS, a subnet being "public" only means it has a route to an Internet Gateway. It does NOT mean instances launched there automatically receive a public IP. That's a separate, independent setting — `map_public_ip_on_launch` on the subnet (or `associate_public_ip_address` on the instance directly). This attribute was missing from the public subnet resource in the VPC module.

**Fix:** Added `map_public_ip_on_launch = true` to the `aws_subnet "public"` resource. Destroyed and re-applied — instance received a public IP (`3.254.56.172`) on the next launch. Confirmed reachable via `nc -zv` on port 22.

**Why this matters:** This is a genuinely common AWS misconception — assuming "public subnet" automatically means "public IP." Understanding that these are two independent controls (subnet-level routing vs instance-level IP assignment) is the kind of distinction that comes up directly in interviews.

## Other learnings

- `data` sources query existing AWS state rather than creating resources — used here to dynamically resolve the latest AMI instead of hardcoding an ID that goes stale
- Module composition requires no explicit `depends_on` — referencing `module.vpc.vpc_id` inside the EC2 module call is enough for Terraform to build the correct dependency graph automatically
- Terraform parallelises independent resource creation — the EC2 instance finished in 14s while the NAT Gateway (which it didn't depend on) was still creating in the background for almost 2 minutes
- Security groups control whether traffic CAN reach an instance — they say nothing about whether anything is listening on that port inside the instance (port 80 "connection refused" despite open security group, because no web server was installed)
- Accidentally committing the `.terraform/` provider binary (648MB) breaks GitHub's 100MB file limit — fixed with `git filter-branch` to purge it from history, plus a proper `.gitignore` going forward

## Files

terraform-aws-modules/
  modules/
    vpc/
      main.tf
      variables.tf
      outputs.tf
    ec2/
      main.tf
      variables.tf
      outputs.tf
  examples/
    vpc-only/
      main.tf
    vpc-with-ec2/
      main.tf
  .gitignore

## Commands used

```bash
# Module development cycle
terraform init
terraform plan
terraform apply
terraform output
terraform destroy

# Debugging the public IP issue
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=tag:Name,Values=manisha-web-server" \
  --query "Reservations[].Instances[].{PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,SubnetId:SubnetId}" \
  --output table

# Verifying connectivity after fix
nc -zv -w3 <public-ip> 22
```