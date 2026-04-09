resource "aws_iam_policy" "secrets_policy" {
  name = "${local.name}-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "${aws_secretsmanager_secret.rds_secret.arn}*"
      }
    ]
  })
}

resource "aws_iam_role" "secrets_irsa_role" {
  name = "${local.name}-secrets-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc_provider.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub" = "system:serviceaccount:default:nodejs-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_attach" {
  policy_arn = aws_iam_policy.secrets_policy.arn
  role       = aws_iam_role.secrets_irsa_role.name
}

output "secret_csi_iam_role_arn" {
  description = "Secret CSI IAM Role ARN"
  value = aws_iam_role.secrets_irsa_role.arn
}

resource "kubernetes_service_account_v1" "nodejs_sa" {
  metadata {
    name      = "nodejs-sa"
    namespace = "default"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.secrets_irsa_role.arn
    }
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}