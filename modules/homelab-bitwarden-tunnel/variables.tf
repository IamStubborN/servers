variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare zone ID for example.com."
  type        = string
}

variable "hostname" {
  description = "Public hostname served by the tunnel."
  type        = string
  default     = "vaultwarden.example.com"
}

variable "origin_service" {
  description = "Origin URL reachable from cloudflared (Docker DNS on proxy network)."
  type        = string
  default     = "http://bitwarden:80"
}

variable "tunnel_name" {
  description = "Cloudflare Tunnel name."
  type        = string
  default     = "homelab-bitwarden"
}
