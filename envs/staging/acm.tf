################################################################################
# 1. שליפת ה-Hosted Zone שקנית ב-AWS
################################################################################
data "aws_route53_zone" "selected" {
  name         = "twodo-app.org"
  private_zone = false
}

################################################################################
# 2. בקשת תעודת SSL עם הטאגים הנכונים לגילוי אוטומטי
################################################################################
resource "aws_acm_certificate" "cert" {
  domain_name       = "twodo-app.org"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.twodo-app.org"
  ]

  tags = {
    Name                                  = "twodo-app-ssl"
    "elbv2.k8s.aws/certificate-discovery" = "twodo-app-stack"
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# 3. יצירת רשומות האימות ב-DNS
################################################################################
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

################################################################################
# 4. האימות עצמו - מבטיח שטרפורם לא ימשיך עד שהתעודה במצב ISSUED
################################################################################
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# הערה: אנחנו משאירים את ה-Output רק ליתר ביטחון, 
# למרות שב-YAML אנחנו נשתמש בשיטה האוטומטית ולא נדביק אותו ידנית.
output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}
################################################################################
# 5. שליפת הנתונים של ה-Load Balancer שנוצר על ידי ה-Ingress
# הערה: זה יעבוד רק אחרי ש-ArgoCD יסיים להקים את ה-Ingress ב-AWS
################################################################################
data "aws_lb" "ingress_lb" {
  tags = {
    "ingress.k8s.aws/stack" = "twodo-app-stack"
  }
}

################################################################################
# 6. יצירת רשומת ה-DNS (Alias) שמחברת את twodo-app.org ל-Load Balancer
################################################################################
resource "aws_route53_record" "app_alias" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "twodo-app.org"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress_lb.dns_name
    zone_id                = data.aws_lb.ingress_lb.zone_id
    evaluate_target_health = true
  }
}