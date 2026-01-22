variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "twodo-app"
}

# --- תוספת עבור אבטחת מידע ---

variable "db_user" {
  description = "Database administrator username"
  type        = string
  default     = "user" # הערך שמופיע כרגע ב-values.yaml שלך
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true   # מונע מהסיסמה להיות מודפסת למסך בהרצה
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "twodo_db"
}