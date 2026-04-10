
/*
"Why do you need output values — can't you just reference the module 
directly?"

"You can reference module.vpc.vpc_id directly anywhere in the same 
Terraform root module. Outputs become essential when you split into 
multiple Terraform state files — a separate eks-cluster state like 02-ebs folder
needs the VPC ID from the vpc state. You'd use terraform_remote_state
data source to read the outputs from the other state file. 
This is called state separation and is a best practice for large
projects."
*/

# VPC Output Values

# VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# VPC CIDR blocks
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# VPC Private Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

# VPC Public Subnets
output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# VPC NAT gateway Public IP
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# VPC AZs
output "azs" {
  description = "A list of availability zones spefified as argument to this module"
  value       = module.vpc.azs
}

/*
for ex if other state in my project want to access below output from this state how would it use?
output "vpc_id" {
  description = "The ID of the VPC"
value       = module.vpc.vpc_id
}

The mechanism — terraform_remote_state
In your other state (say 02-eks-cluster or 03-rds), 
you'd add this data source:
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "terraform-on-aws-eks-jaspal"       # same bucket as your backend
    key    = "dev/eks-cluster/terraform.tfstate" # the KEY of the state you want to READ
    region = "us-east-1"
  }
}
Then anywhere in that same state you reference it like:

resource "aws_eks_cluster" "eks_cluster" {
  name = "my-cluster"

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets
    # ↑ reads your output "private_subnets" from the VPC state
  }
}

resource "aws_db_subnet_group" "rds_subnet" {
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets
}

resource "aws_security_group" "rds_sg" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  # ↑ reads your output "vpc_id"
}

Why this matters — the real architecture pattern
In your project currently everything is in one state file. 
That's fine for learning. But in real teams projects are split 
like this:

dev/
  vpc/terraform.tfstate          ← owns VPC, subnets, NAT
  eks-cluster/terraform.tfstate  ← reads vpc outputs, owns EKS
  rds/terraform.tfstate          ← reads vpc outputs, owns RDS
  app/terraform.tfstate          ← reads eks + rds outputs, owns K8s resources

Each state only owns what it creates, but can read outputs from any other state via terraform_remote_state.


"What's the risk of terraform_remote_state?"

"It creates a hard coupling between states. If the VPC state's output
 name changes — say from vpc_id to network_id — every downstream 
 state that reads it breaks on the next terraform plan. 
 You need to version output name changes carefully, 
 like deprecating the old name while adding the new one before 
 removing it."


"Is there an alternative to terraform_remote_state?"

"Yes — AWS SSM Parameter Store or AWS Secrets Manager as a middle 
layer. The VPC state writes its outputs to SSM parameters like /dev/vpc/vpc_id, and the EKS state reads them with data.aws_ssm_parameter. This decouples the states completely — the EKS state doesn't need to know anything about the VPC's S3 backend config. It's more loosely coupled but adds extra resources to manage."
*/