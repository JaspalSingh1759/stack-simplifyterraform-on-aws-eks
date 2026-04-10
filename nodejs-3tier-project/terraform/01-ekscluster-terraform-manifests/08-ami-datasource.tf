/*
"Why use a data source for AMI instead of hardcoding the AMI ID?"

"AMI IDs are region-specific and get deprecated. If I hardcode 
ami-0abcdef1234567890, it works today but in 6 months that AMI 
might be decommissioned or have unpatched CVEs. 
Using most_recent = true with filters always gives the latest 
patched Amazon Linux 2 image. The tradeoff is that terraform apply
 on different days might use different AMIs — if you want 
 reproducibility, pin the AMI ID in a variable."

"What's the difference between a data block and a resource block?"

"resource creates and manages infrastructure — Terraform owns it and
 will destroy it on terraform destroy. data is read-only — Terraform
  queries existing AWS resources and makes the result available for 
  reference. Data sources don't appear in terraform destroy and don't
   create anything."

"What happens if the AMI filter matches nothing?"

"Terraform errors during the plan phase with 'no results found'. 
This is actually caught early — before any resources are created — 
because data sources are evaluated during terraform plan."

*/


# Get latest AMI ID for Amazon Linux2 OS
data "aws_ami" "amzlinux2" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "amzn2-ami-hvm-*-gp2" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}