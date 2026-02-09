################################################################################
# 1. שליפת ה-Hosted Zone
################################################################################
data "aws_route53_zone" "selected" {
  name         = "twodo-app.org"
  private_zone = false
}

################################################################################
# 2. בקשת תעודת SSL עם Discovery Tag
################################################################################
resource "aws_acm_certificate" "cert" {
  domain_name       = "twodo-app.org"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.twodo-app.org"
  ]

  tags = {
    Name                                  = "twodo-app-ssl"
    # הטאג הזה קריטי - ה-LB Controller ימצא את התעודה בזכותו
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
# 4. האימות עצמו
################################################################################
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}