
/*
"Why use locals instead of just repeating the value?"

"DRY principle. If local.name is dev-hr-eks and it's used in 20 
resource names, you change it in one place. Also locals can be 
computed — like concatenating var.environment and 
var.business_division — which variables alone can't do."
*/

# Define Local Values in Terraform
locals {
  owners = var.business_divsion
  environment = var.environment
  name = "${var.business_divsion}-${var.environment}"
  #name = "${local.owners}-${local.environment}"
  common_tags = {
    owners = local.owners
    environment = local.environment
  }
  eks_cluster_name = "${local.name}-${var.cluster_name}"  
} 