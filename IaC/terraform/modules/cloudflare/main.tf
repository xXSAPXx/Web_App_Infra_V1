
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
resource "cloudflare_dns_record" "subdomain_to_alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = var.comment                                 #
  name    = var.sub_domain_name                         # Creates www.xxsapxx.uk
  type    = var.dns_record_type                         # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
  ttl     = var.dns_ttl                                 # DNS Record TTL 
  proxied = var.proxied                                 # Enables Cloudflare HTTPS + caching                                        
}


# Change Cloudflare ROOT Record to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "root_domain_to_alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = var.root_domain_comment                     #
  name    = var.root_domain_name                        # Creates xxsapxx.uk
  type    = var.root_dns_record_type                    # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name                            # Attach DNS Record to AWS ALB CNAME
  ttl     = var.root_dns_ttl                            # DNS Record TTL 
  proxied = var.root_proxied                            # Enables Cloudflare HTTPS + caching                                        
}


# Cloudflare Rule to Redirect traffic from ROOT to WWW: 
resource "cloudflare_ruleset" "redirect_root_to_www" {
  name    = var.rule_name
  zone_id = var.cloudflare_zone_id
  kind    = var.rule_kind
  phase   = var.rule_phase

  rules = [
    {
      action      = var.rule_action
      expression  = var.rule_expression
      description = var.rule_description
      enabled     = var.rule_enabled

      action_parameters = {
        from_value = {
          status_code = var.rule_status_code
          target_url = {
            value = var.rule_redirect_to
          }
          # It's good practice to decide if we want to keep the query string:
          preserve_query_string = var.rule_preserve_query_string
        }
      }
    }
  ]
}

# Use a redirect rule to enforce https:// (not just http → https at ALB level) -- Cloudflare: (Always Use HTTPS)
resource "cloudflare_zone_setting" "https" {
  zone_id           = var.cloudflare_zone_id
  setting_id        = var.setting_id
  value             = var.always_use_https_value
}
