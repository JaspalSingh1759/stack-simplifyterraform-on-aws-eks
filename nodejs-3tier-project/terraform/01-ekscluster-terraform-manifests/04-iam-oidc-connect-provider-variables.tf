# Input Variables - AWS IAM OIDC Connect Provider


# EKS OIDC ROOT CA Thumbprint - valid until 2037
variable "eks_oidc_root_ca_thumbprint" {
  type        = string
  description = "Thumbprint of Root CA for EKS OIDC, Valid until 2037"
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

/*
"What is the OIDC thumbprint and why is it hardcoded?"

"It's the SHA-1 fingerprint of the root Certificate Authority that 
signed EKS's OIDC endpoint certificate. AWS IAM uses it to verify 
the OIDC provider is legitimate. It's hardcoded because this CA cert 
doesn't change frequently — it's valid until 2037. In production 
you'd fetch it dynamically using the tls provider's tls_certificate 
data source instead of hardcoding."
*/
