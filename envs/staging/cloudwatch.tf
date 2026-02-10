################################################################################
# AWS Cloudwatch Logs & Observability
################################################################################

# 1. התקנת ה-Add-on ששולח לוגים ומטריקות ל-AWS
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [module.eks]
}

# 2. חיבור הפוליסי ל-Role של ה-Nodes (התיקון הקריטי)
# הפעולה הזו נותנת לשרתים רשות לכתוב ל-Cloudwatch Logs
resource "aws_iam_role_policy_attachment" "nodes_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  # כאן אנחנו משתמשים בשם "general" כפי שהגדרת ב-main.tf
  role       = module.eks.eks_managed_node_groups["general"].iam_role_name
}

# 3. יצירת ה-Log Group של האפליקציה עם זמן שמירה של שבוע
resource "aws_cloudwatch_log_group" "eks_app_logs" {
  name              = "/aws/containerinsights/${module.eks.cluster_name}/application"
  retention_in_days = 7
}