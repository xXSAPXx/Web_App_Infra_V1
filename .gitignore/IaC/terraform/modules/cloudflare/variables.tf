

# Set Variable for CloudFlare API_KEY: 
variable "cloudflare_api_token" {
  type        = string
  description = "API token with DNS edit permissions"
  sensitive   = true
  nullable    = false
}


# Set Variable for CloudFlare ZONE_ID: 
variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID for the Cloudflare domain"
  sensitive   = true
  nullable    = false
}


variable "domain_name" {
  type        = string
  description = "Domain name managed in Cloudflare (e.g., xxsapxx.uk)"
}


variable "alb_dns_name" {
  type        = string
  description = "The DNS name of the AWS ALB to point the CNAME record to"
}
