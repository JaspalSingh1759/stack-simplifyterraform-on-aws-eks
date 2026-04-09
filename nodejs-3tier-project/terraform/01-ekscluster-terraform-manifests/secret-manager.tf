resource "aws_secretsmanager_secret" "rds_secret" {
  name = "nodejs-rds-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_secret_value" {
  secret_id = aws_secretsmanager_secret.rds_secret.id
  
  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.mysql.address
    DB_PORT     = tostring(aws_db_instance.mysql.port)
    DB_NAME     = aws_db_instance.mysql.db_name
    DB_USERNAME = aws_db_instance.mysql.username
    DB_PASSWORD = aws_db_instance.mysql.password
  })
}