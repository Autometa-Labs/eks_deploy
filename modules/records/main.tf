resource "aws_route53_record" "records" {
  zone_id = var.route53_zone_id
  name    = var.record_name
  type    = var.record_type
  ttl     = var.record_ttl
  records = [var.elb_dns_name]
}