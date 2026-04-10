/*
terraform init
  → reads required_providers block
  → downloads aws ~5.31, helm ~2.9, http ~3.3
  → connects to S3 bucket "terraform-on-aws-eks-jaspal"
  → reads/creates state file at key "dev/eks-cluster/terraform.tfstate"
  → creates DynamoDB lock entry in "dev-ekscluster"

"What happens if two engineers run terraform apply at the same time?"

"DynamoDB creates a lock record with the state file path as the key. The second apply reads that lock, sees it's taken, and exits with a lock error showing who holds it and since when. You can force-unlock with terraform force-unlock <lock-id> but only do that if you're certain the first apply is truly dead — not just slow."

"What's stored in the S3 state file?"

"Everything Terraform knows about your infrastructure — every resource ID, every attribute, every dependency. It's the source of truth. If you delete it, Terraform thinks nothing exists and will try to recreate everything, potentially duplicating resources."

"Why >= 5.31 for AWS provider but ~> 2.9 for Helm?"

"The AWS provider has a stable API — >= means we're happy with any new version. Helm 3.x had breaking changes between minor versions, so ~> 2.9 is safer — it allows 2.9, 2.10, 2.11 but blocks 3.0."
*/

# Terraform Settings Block
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = ">= 4.65"
      version = ">= 5.31"      
     }

    helm = {
      source = "hashicorp/helm"
      #version = "2.4.1"
      #version = "~> 2.4"
      version = "~> 2.9"
    }
    http = {
      source = "hashicorp/http"
      #version = "2.1.0"
      #version = "~> 2.1"
      version = "~> 3.3"
    }

  }
  # Adding Backend as S3 for Remote State Storage
  backend "s3" {
    bucket = "terraform-on-aws-eks-jaspal"
    key    = "dev/eks-cluster/terraform.tfstate"
    region = "us-east-1" 
 
    # For State Locking
    dynamodb_table = "dev-ekscluster"    
  }  
}

# Terraform Provider Block
provider "aws" {
  region = var.aws_region
}