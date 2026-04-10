# IAM Role for EKS Node Group 
resource "aws_iam_role" "eks_nodegroup_role" {
  name = "${local.name}-eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_role.name
}
/*
"What is sts:AssumeRole in the trust policy?"

"It's the action that allows the principal — in this case EC2 — 
to assume the IAM role and get temporary credentials. Without this 
in the trust policy, even if you attach 100 permission policies, 
the EC2 instance can't use the role. The trust policy answers 'who 
can use this role' and the permission policies answer 'what can they
 do'."

"Why use AWS managed policies instead of custom ones for node groups?"

"AWS managed policies are maintained by AWS — if EKS adds new API 
calls internally that require new permissions, AWS updates the 
managed policy automatically. If you used a custom inline policy and
 EKS changed internals, your nodes could silently break. The tradeoff
  is managed policies are broader than necessary — least-privilege 
  purists would create custom policies but it's rarely worth the 
  maintenance burden for node groups."
*/