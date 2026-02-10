# 1. יצירת ה-OIDC Provider עבור GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # thumbprints מעודכנים עבור GitHub Actions
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# 2. יצירת ה-Role ש-GitHub Actions יקבל (Assume Role)
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-prod-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          #Federated = aws_iam_openid_connect_provider.github.arn
          Federated = "arn:aws:iam::993412842562:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringLike = {
            # הגבלה ביטחונית קריטית: רק הריפו שלך יכול להשתמש ברול
            "token.actions.githubusercontent.com:sub" = "repo:Amitbush/twodo-app:*"
          }
        }
      }
    ]
  })
}

# 3. מתן הרשאות לניהול ECR (בנייה, דחיפה וקבלת Token)
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.github_actions_role.name
  # PowerUser מאפשר GetAuthorizationToken וגם Push/Pull
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# 4. פלט של ה-ARN לשימוש ב-Workflow
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}