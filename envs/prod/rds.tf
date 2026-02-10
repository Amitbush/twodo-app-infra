################################################################################
# RDS Security Group - מי יכול לדבר עם ה-Database
################################################################################
resource "aws_security_group" "rds_sg" {
  name        = "twodo-prod-rds-sg"
  description = "Allow inbound traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  # מאפשר רק לפורט של Postgres להיכנס (5432)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # מאפשר לכל ה-VPC לדבר איתו (כולל ה-EKS Nodes)
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# DB Subnet Group - איפה ה-DB יושב פיזית
################################################################################
resource "aws_db_subnet_group" "postgres" {
  name       = "twodo-prod-db-subnet-group"
  subnet_ids = module.vpc.public_subnets # משתמש בסאבנטים הציבוריים שהגדרת ב-VPC

  tags = {
    Name = "Twodo Prod DB Subnet Group"
  }
}

################################################################################
# RDS Instance - מסד הנתונים עצמו
################################################################################
resource "aws_db_instance" "postgres" {
  identifier           = "twodo-db-prod"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro" # חסכוני ומתאים לפרויקט
  
  # שימוש במשתנים שכבר הגדרת ב-variables.tf
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  publicly_accessible  = true  # מאפשר לך להתחבר עם DBeaver/TablePlus מהבית
  skip_final_snapshot  = true  # מאפשר מחיקה מהירה של ה-DB בסיום הפרויקט
  
  tags = {
    Name = "Twodo-Prod-Postgres-RDS"
  }
}
