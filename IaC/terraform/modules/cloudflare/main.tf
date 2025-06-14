
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


# Change Cloudflare DNS Records to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = var.comment                                 #
  name    = var.sub_domain_name                         # Creates www.xxsapxx.uk
  type    = var.dns_record_type                         # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
  ttl     = var.dns_ttl                                 # DNS Record TTL 
  proxied = var.proxied                                 # Enables Cloudflare HTTPS + caching                                        
}


# Change Cloudflare ROOT Record to point to the AWS ALB DNS Name: 
#resource "cloudflare_dns_record" "alb_record" { 
#  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
#  comment = var.root_domain_comment                     #
#  name    = var.root_domain_name                        # Creates xxsapxx.uk
#  type    = var.root_dns_record_type                    # ALB doesn't have static IP, use CNAME
#  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
#  ttl     = var.root_dns_ttl                            # DNS Record TTL 
#  proxied = var.root_proxied                            # Enables Cloudflare HTTPS + caching                                        
#}


# Cloudflare Rule to Redirect traffic from ROOT to WWW: 
#resource "cloudflare_ruleset" "redirect_root_to_www" {
#  name      = "Redirect root to www"
#  zone_id   = var.cloudflare_zone_id
#  kind      = "zone"
#  phase     = "http_request_redirect"

#  rules {
#    enabled     = true
#    description = "Redirect root domain to www"
#
#    expression = "(http.host eq \"xxsapxx.uk\")"
#
#    action = "redirect"
#
#    action_parameters {
#      status_code = 301
#      url         = "https://www.xxsapxx.uk"
#    }
#  }
#}




#Use a redirect rule to enforce https:// (not just http → https at ALB level) -- Cloudflare: (Always Use HTTPS)
#resource "cloudflare_zone_settings_override" "https" {
#  zone_id = data.cloudflare_zone.this.id
#  settings {
#    always_use_https = "on"
#  }
#}
