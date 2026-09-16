output "tunnel_id" {
  description = "Cloudflare Tunnel UUID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.name
}

output "tunnel_cname" {
  description = "CNAME target for the public hostname."
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

output "tunnel_token" {
  description = "Token for cloudflared tunnel run (homelab bitwarden-cloudflared)."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}

output "hostname" {
  description = "Public hostname."
  value       = var.hostname
}
