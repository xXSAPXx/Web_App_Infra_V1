
# Required Module Providers: 
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
    }
 }
}


# Select Domain: 
data "cloudflare_zones" "selected" {
    name = var.select_domain_name
}


# Change DNS Records to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = var.comment                                 #
  name    = var.sub_domain_name                         # Creates www.xxsapxx.uk
  type    = var.dns_record_type                         # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
  ttl     = var.dns_ttl                                 # DNS Record TTL 
  proxied = var.proxied                                 # Enables Cloudflare HTTPS + caching                                        
}



