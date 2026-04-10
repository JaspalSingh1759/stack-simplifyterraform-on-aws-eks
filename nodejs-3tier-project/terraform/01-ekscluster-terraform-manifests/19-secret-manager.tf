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

/*
"Why two resources — aws_secretsmanager_secret and 
aws_secretsmanager_secret_version?"

"The secret is like a folder — it has metadata, name, policies, 
rotation config. The secret version is the actual value inside it. 
AWS supports multiple versions simultaneously (for rotation — old 
value stays accessible while apps transition to new value). 
Terraform separates them so you can update the value without 
recreating the secret container and losing its ARN 
(which would break IAM policies referencing it)."

"What is recovery_window_in_days = 0?"

"Secrets Manager has a deletion protection feature — by default a 
deleted secret enters a recovery window (7-30 days) where you can 
restore it. Setting it to 0 bypasses that and deletes immediately. 
Essential in dev/test where terraform destroy followed by terraform 
apply would fail — the secret name nodejs-rds-secret would already 
be 'deleted but recoverable' and you can't create a new one with the 
same name during the window."
*/