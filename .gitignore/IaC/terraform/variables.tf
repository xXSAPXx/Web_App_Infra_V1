
# Cloudflare Variables: 
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID of the Cloudflare domain"
}
