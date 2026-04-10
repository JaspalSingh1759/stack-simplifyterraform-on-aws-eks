# Datasource: AWS Partition
# Use this data source to lookup information about the current AWS partition in which Terraform is working
data "aws_partition" "current" {}

# Resource: AWS IAM Open ID Connect Provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.${data.aws_partition.current.dns_suffix}"]
  thumbprint_list = [var.eks_oidc_root_ca_thumbprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = merge(
    {
      Name = "${var.cluster_name}-eks-irsa"
    },
    local.common_tags
  )
}

# Output: AWS IAM Open ID Connect Provider ARN
output "aws_iam_openid_connect_provider_arn" {
  description = "AWS IAM Open ID Connect Provider ARN"
  value = aws_iam_openid_connect_provider.oidc_provider.arn 
}

# Extract OIDC Provider from OIDC Provider ARN
locals {
    aws_iam_oidc_connect_provider_extract_from_arn = element(split("oidc-provider/", "${aws_iam_openid_connect_provider.oidc_provider.arn}"), 1)
}

# Output: AWS IAM Open ID Connect Provider
output "aws_iam_openid_connect_provider_extract_from_arn" {
  description = "AWS IAM Open ID Connect Provider extract from ARN"
   value = local.aws_iam_oidc_connect_provider_extract_from_arn
}

# Sample Outputs for Reference
/*
aws_iam_openid_connect_provider_arn = "arn:aws:iam::180789647333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A9DED4A4FA341C2A5D985A260650F232"
aws_iam_openid_connect_provider_extract_from_arn = "oidc.eks.us-east-1.amazonaws.com/id/A9DED4A4FA341C2A5D985A260650F232"
*/

/*
"Can you explain exactly how IRSA works step by step?"

"Step 1: EKS has an OIDC endpoint that issues signed JWT tokens to 
pods via service accounts. Step 2: I register that OIDC endpoint 
with AWS IAM using aws_iam_openid_connect_provider — now AWS IAM 
trusts tokens from my cluster. Step 3: I create an IAM role whose 
trust policy says 'trust tokens from this OIDC provider for service 
account nodejs-sa in namespace default'. Step 4: My Kubernetes 
service account is annotated with that role ARN. Step 5: When a 
pod uses that service account, the EKS pod identity webhook mutates 
the pod to inject the service account token and set AWS_ROLE_ARN and 
AWS_WEB_IDENTITY_TOKEN_FILE env vars. Step 6: The AWS SDK in the pod 
(or the CSI driver) automatically uses those to call 
sts:AssumeRoleWithWebIdentity and gets temporary credentials."

"What's the OIDC thumbprint variable for?"

"When you register an OIDC provider with IAM, AWS needs the 
thumbprint of the root CA certificate to validate the OIDC endpoint
 is legitimate. It's essentially SSL certificate pinning at the IAM 
 level."
*/