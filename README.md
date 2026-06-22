# Terraform AWS Modules
# Week3- Terraform AWS Modules — VPC and EC2 from scratch

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

```
terraform-aws-modules/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── examples/
│   ├── vpc-only/
│   │   └── main.tf
│   └── vpc-with-ec2/
│       └── main.tf
└── .gitignore
```

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
## Week 4 — Security scanning with tfsec and checkov

### Tools installed
- `tfsec v1.28.14` — Terraform-specific security scanner
- `checkov 3.3.1` — broader IaC security scanner
- `terragrunt v1.0.8` — Terraform wrapper for multi-environment DRY config

### Security improvements made to modules

#### EC2 module (`modules/ec2`)
- SSH ingress restricted from `0.0.0.0/0` to `var.allowed_cidr_blocks` (default `10.0.0.0/8` — VPN/private range only)
- Added IMDSv2 enforcement via `metadata_options { http_tokens = "required" }`
- Added EBS root volume encryption via `root_block_device { encrypted = true }`
- Added EC2 detailed monitoring via `monitoring = true`
- Added `allowed_cidr_blocks` variable — forces caller to make conscious SSH access decision

#### VPC module (`modules/vpc`)
- Added VPC Flow Logs → CloudWatch Log Group with 365-day retention
- Added KMS encryption for the flow log CloudWatch Log Group
- Added IAM role + scoped policy for flow logs (resource-specific ARN, not wildcard)
- Added `aws_default_security_group` to restrict default VPC security group traffic
- Added conscious ignore comments for accepted architecture decisions

### tfsec result

```
Before: 3 critical, 4 high, 1 medium
After:  0 critical, 0 high, 0 medium — No problems detected
```

### checkov result

```
Passed: 39, Failed: 3 (accepted), Skipped: 4 (documented)
```

### Consciously accepted findings

| Check | Reason |
|---|---|
| HTTP open to internet | Web server intentionally public-facing |
| Egress 0.0.0.0/0 | Standard practice — unrestricted outbound normal |
| Public subnet assigns public IPs | Intentional for this architecture |
| EBS optimization | False positive — t3 instances always EBS-optimized by default |
| No IAM role on EC2 | Accepted for learning project |
| KMS key no explicit policy | Default policy grants account root — acceptable |

### Key lesson

Security tools produce false positives. The right approach is not to blindly fix everything — it's to understand each finding, assess the real risk, and document conscious decisions with ignore comments. The comment IS the documentation.

## Week 4 (continued) — Terragrunt multi-environment setup

### What is Terragrunt?

Terragrunt is a wrapper around Terraform that eliminates repetition across multiple environments. Instead of copying the same Terraform config for dev, staging, and prod with tiny differences, Terragrunt lets you define shared config once and override only what differs per environment.

### Structure built

```
terraform-aws-modules/
  root.hcl                        # shared config: remote state, provider
  environments/
    dev/terragrunt.hcl            # dev-specific inputs only
    staging/terragrunt.hcl        # staging-specific inputs only
    prod/terragrunt.hcl           # prod-specific inputs only
```

### root.hcl — shared config once

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket       = "manisha-terraform-state-eu-west-1"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true   # S3 native locking — no DynamoDB needed (requires Terraform 1.10+)
  }
}
```

`path_relative_to_include()` returns the relative path from root to the child config:
- dev  → `environments/dev/terraform.tfstate`
- staging → `environments/staging/terraform.tfstate`
- prod → `environments/prod/terraform.tfstate`

Each environment gets its own isolated state file automatically.

### Environment config — only what differs

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/vpc"
}

inputs = {
  vpc_name             = "manisha-dev-vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]
  environment          = "dev"
}
```

### CIDR ranges — non-overlapping by design

```
dev:     10.0.0.0/16
staging: 10.1.0.0/16
prod:    10.2.0.0/16
```

Non-overlapping so environments can be connected via VPC peering in future without routing conflicts.

### Remote state — S3 with native locking

State stored in S3: `manisha-terraform-state-eu-west-1`
Locking via S3 native conditional writes (Terraform 1.10+) — no DynamoDB required.

Confirmed working — plan output showed:
```
Releasing state lock. This may take a few moments...
```

### Commands

```bash
# Plan a specific environment
cd environments/dev
terragrunt plan

# Apply a specific environment
terragrunt apply

# Plan all environments at once (from repo root)
terragrunt run-all plan

# Destroy a specific environment
terragrunt destroy
```

### Key learnings

- `path_relative_to_include()` — Terragrunt function that returns path from root config to child config. Used to give each environment a unique S3 state key automatically.
- `find_in_parent_folders("root.hcl")` — walks up directory tree to find the root config. Child configs inherit everything from it.
- S3 native locking requires Terraform 1.10+ — older versions need DynamoDB. We upgraded from 1.5.7 to 1.15.6 specifically for this.
- Using `terragrunt.hcl` as the root file is deprecated in Terragrunt 1.0+ — use `root.hcl` instead.

### Interview answer — "how do you manage multiple environments in Terraform?"

"We use Terragrunt with a root config that defines shared backend and provider settings, and per-environment configs that only contain what differs — variable values, CIDR ranges, resource names. State is stored in S3 with native locking (no DynamoDB needed since Terraform 1.10). Each environment has its own isolated state file at a path derived automatically from the directory structure. This means adding a new environment is just creating one new file with the environment-specific inputs — no copy-pasting Terraform code."