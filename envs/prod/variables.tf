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

# --- משתנים לניהול הטאגים של הקלאסטר (למניעת שגיאות Subnet) ---

variable "cluster_tag_key" {
  description = "The tag key used for EKS cluster resource discovery"
  type        = string
  default     = "kubernetes.io/cluster/twodo-prod-eks"
}

variable "elb_tag_key" {
  description = "The tag key for public ELB discovery"
  type        = string
  default     = "kubernetes.io/role/elb"
}

# --- תוספת עבור אבטחת מידע (מסד נתונים) ---

variable "db_user" {
  description = "Database administrator username"
  type        = string
  default     = "twodo_admin"
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true   # מונע מהסיסמה להיות מודפסת למסך
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "twodo_db"
}