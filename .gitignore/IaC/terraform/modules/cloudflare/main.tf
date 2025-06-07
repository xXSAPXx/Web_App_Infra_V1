# Cloudflare Provider: 
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}


# Select Domain: 
data "cloudflare_zones" "selected" {
    name = "xxsapxx.uk"
}


# Change DNS Records to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = "Domain pointed to AWS_ALB"                 #
  name    = "www"                                       # Creates www.xxsapxx.uk
  type    = "CNAME"                                     # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
  ttl     = 1                                           # DNS Record TTL 
  proxied = true                                        # Enables Cloudflare HTTPS + caching                                        
}



