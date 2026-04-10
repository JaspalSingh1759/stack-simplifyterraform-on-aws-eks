
/*
"What's the difference between a variable and a local in Terraform?"

"A variable is an input — someone can pass it in via terraform.tfvars,
 CLI -var flag, or environment variable TF_VAR_*. A local is computed
  inside the config — it's like a constant derived from variables. 
  You can't override a local from outside."
*/

# Input Variables
# AWS Region
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type = string
  default = "us-east-1"  
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type = string
  default = "dev"
}
# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type = string
  default = "SAP"
}
