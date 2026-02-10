################################################################################
# 5. Secrets
################################################################################

resource "kubernetes_secret" "twodo_secrets" {
  metadata {
    name      = "twodo-secrets"
    namespace = "default"
  }

  data = {
    # ה-URL מעודכן לשימוש בכתובת ה-RDS שנוצר ב-rds.tf
    db-url            = "postgresql://${var.db_user}:${var.db_password}@${element(split(":", aws_db_instance.postgres.endpoint), 0)}:5432/${var.db_name}"
    db-user           = var.db_user
    db-password       = var.db_password
    postgres-password = var.db_password
    api-url           = "/api"
  }

  # מבטיח שה-Secret ייווצר/יתעדכן רק אחרי שה-RDS מוכן
  depends_on = [aws_db_instance.postgres]
}