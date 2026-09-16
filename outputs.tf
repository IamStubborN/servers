output "oracle_instance_id" {
  description = "Oracle runner instance OCID."
  value       = module.oracle.id
  sensitive   = true
}

output "oracle_public_ip" {
  description = "Oracle runner public IP."
  value       = module.oracle.public_ip
  sensitive   = true
}

output "bitwarden_tunnel_id" {
  description = "Homelab Bitwarden Cloudflare Tunnel ID."
  value       = module.homelab_bitwarden_tunnel.tunnel_id
}

output "bitwarden_tunnel_hostname" {
  description = "Public hostname for Vaultwarden Send links."
  value       = module.homelab_bitwarden_tunnel.hostname
}

output "bitwarden_tunnel_token" {
  description = "cloudflared token for homelab bitwarden-cloudflared."
  value       = module.homelab_bitwarden_tunnel.tunnel_token
  sensitive   = true
}
