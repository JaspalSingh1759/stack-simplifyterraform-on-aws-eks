resource "kubernetes_config_map" "db_config" {
  metadata {
    name      = "db-config"
    namespace = "default"
  }

  data = {
    DB_HOST = aws_db_instance.rds.endpoint
  }

  depends_on = [aws_db_instance.rds,
                module.eks
  ]
}