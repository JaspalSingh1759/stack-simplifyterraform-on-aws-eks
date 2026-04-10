/*
Creates in order:
1. VPC (aws_vpc)
2. Internet Gateway (aws_internet_gateway)
3. Public subnets × N AZs
4. Private subnets × N AZs
5. Database subnets × N AZs
6. Database subnet group (aws_db_subnet_group via module)
7. NAT Gateway Elastic IP
8. NAT Gateway (in public subnet)
9. Route tables (public, private, database)
10. Route table associations
*/

# AWS Availability Zones Datasource
data "aws_availability_zones" "available" {
}

# Create VPC Terraform Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  #version = "4.0.1"
  version = "5.4.0"    
  
  # VPC Basic Details
  name = local.eks_cluster_name
  cidr = var.vpc_cidr_block
  azs             = data.aws_availability_zones.available.names
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets  

  # Database Subnets
  database_subnets = var.vpc_database_subnets
  create_database_subnet_group = var.vpc_create_database_subnet_group
  create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  # create_database_internet_gateway_route = true
  # create_database_nat_gateway_route = true
  
  # NAT Gateways - Outbound Communication
  enable_nat_gateway = var.vpc_enable_nat_gateway 
  single_nat_gateway = var.vpc_single_nat_gateway

  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support   = true

  
  tags = local.common_tags
  vpc_tags = local.common_tags

  # Additional Tags to Subnets
  public_subnet_tags = {
    Type = "Public Subnets"
    "kubernetes.io/role/elb" = 1    
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"        
  }
  private_subnet_tags = {
    Type = "private-subnets"
    "kubernetes.io/role/internal-elb" = 1    
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"    
  }

  database_subnet_tags = {
    Type = "database-subnets"
  }
  # Instances launched into the Public subnet should be assigned a public IP address.
  map_public_ip_on_launch = true
}

/*
"Why are there 3 subnet tiers — couldn't you just use public and private?"

"The database tier is separated for security and compliance. 
Database subnets have no route to the internet gateway — not even through NAT. 
Putting RDS in a 'private' subnet that has NAT means your DB subnet has outbound 
internet access, which is unnecessary for a database. The third tier enforces true network 
isolation."

"What do these Kubernetes tags on subnets actually do?"
hcl"kubernetes.io/role/elb" = 1           # on public subnets
"kubernetes.io/role/internal-elb" = 1  # on private subnets
"kubernetes.io/cluster/${name}" = "shared"

"The AWS Load Balancer Controller (running inside EKS) reads these tags via EC2 API
 calls when it needs to create an ALB or NLB for a Kubernetes Ingress or Service. 
 Without elb=1, the controller can't find which subnets to place the load balancer 
 in and the Ingress will stay in a pending state forever. The shared value on the 
 cluster tag means this VPC is shared across multiple clusters — use owned if 
 only one cluster uses it."

"What's the problem with single_nat_gateway = true in production?"

"Single NAT gateway is a single point of failure. If that AZ goes down, 
all private subnet instances lose internet access — they can't pull images, 
reach AWS APIs, etc. In production you'd set one_nat_gateway_per_az = true so each AZ has its own NAT gateway. It costs more but gives you HA."

"What is map_public_ip_on_launch = true doing?"

"Instances launched into public subnets automatically get a public IP. 
This is what allows your public node group EC2 instances to be reachable — 
otherwise you'd need an Elastic IP. For EKS nodes in public subnets this is 
expected behavior."
*/