variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "Primary Cloudflare zone name."
  type        = string
}

variable "server_ip" {
  description = "Default server IPv4 address for example DNS records."
  type        = string
  default     = "203.0.113.10"
}

variable "dns_records" {
  description = "DNS records for the primary zone."
  type = map(object({
    name    = string
    content = string
    type    = string
    proxied = bool
    ttl     = optional(number, 1)
  }))
  default = null
}

variable "acme_challenge_local_txt" {
  description = "Optional TXT value for _acme-challenge.local."
  type        = string
  default     = ""
  sensitive   = true
}

variable "always_use_https" {
  description = "Cloudflare Always Use HTTPS setting."
  type        = string
  default     = "on"
}

variable "automatic_https_rewrites" {
  description = "Cloudflare Automatic HTTPS Rewrites setting."
  type        = string
  default     = "on"
}

variable "min_tls_version" {
  description = "Minimum TLS version."
  type        = string
  default     = "1.2"
}

variable "ssl_mode" {
  description = "Cloudflare SSL mode."
  type        = string
  default     = "full"
}

variable "r2_buckets" {
  description = "R2 buckets managed in the account."
  type = map(object({
    name     = string
    location = string
  }))
  default = {}
}
