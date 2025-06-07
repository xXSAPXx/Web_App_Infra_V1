

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


variable "select_domain_name" {
  type        = string
  description = "Domain name managed in Cloudflare (e.g., xxsapxx.uk)"
}


variable "comment" {
  type        = string
  description = "Comment for the DNS Record"
}


variable "sub_domain_name" {
  type        = string
  description = "Choose a subdomain for the DNS Record"
}


variable "dns_record_type" {
  type        = string
  description = "DNS Record Type"
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "TXT"], var.dns_record_type)
    error_message = "Only A, AAAA, CNAME, or TXT record types are allowed."
  }
}


variable "dns_ttl" {
  type        = number
  description = "DNS TTL"
  validation {
    condition = contains([1, 120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400], var.dns_ttl)
    error_message = "TTL must be 1 (automatic) or one of Cloudflare’s supported TTL values."
  }
}


variable "proxied" {
  type        = bool
  description = "Proxied through CloudFlare: True/False"
}


variable "alb_dns_name" {
  type        = string
  description = "The DNS name of the AWS ALB to point the CNAME record to"
}
