
output "alb_cname_record" {
  value = cloudflare_dns_record.alb_record.name
}
