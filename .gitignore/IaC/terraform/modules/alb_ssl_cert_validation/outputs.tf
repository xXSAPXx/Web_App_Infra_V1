
output "certificate_arn" {
  value = aws_acm_certificate.alb_cert.arn
}
