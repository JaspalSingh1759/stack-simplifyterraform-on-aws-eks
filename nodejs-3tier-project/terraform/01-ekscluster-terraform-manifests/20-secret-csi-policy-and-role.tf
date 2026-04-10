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
/*
What happens: The final piece — creates the IAM policy, IAM role with OIDC trust, attaches policy, creates the Kubernetes ServiceAccount with the role annotation.
Interview Q&A:
"Why is the OIDC condition scoped to a specific service account?"
hcl"${oidc_url}:sub" = "system:serviceaccount:default:nodejs-sa"

"This is least-privilege for IRSA. Without this condition, ANY pod in ANY namespace using ANY service account could assume this role — if any pod in the cluster gets compromised, the attacker gets your Secrets Manager access. By scoping to system:serviceaccount:default:nodejs-sa, only pods using that specific service account in the default namespace can assume the role."

"What happens if you delete the Kubernetes service account but not the IAM role?"

"The IAM role remains but nothing can assume it (the service account that was annotated with it is gone). You'd recreate the service account and re-annotate it. In Terraform this is managed — both are in the same file, so terraform destroy removes both and terraform apply recreates both."

"Why is depends_on = [aws_eks_cluster.eks_cluster] needed for the service account?"

"The Kubernetes provider needs the EKS cluster to exist and be reachable before it can create any Kubernetes resources. Without the dependency, Terraform might try to create the ServiceAccount before the API server is ready, and the Kubernetes provider would fail to connect."
*/
