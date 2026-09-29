module "oracle" {
  source = "./modules/oracle"

  compartment_ocid    = var.compartment_ocid
  ssh_public_key      = var.ssh_public_key
  agent_flow_repo_url = var.agent_flow_repo_url
}

# Homelab Vaultwarden public ingress (no Oracle/machine changes).
module "homelab_bitwarden_tunnel" {
  source = "./modules/homelab-bitwarden-tunnel"

  account_id     = var.cloudflare_account_id
  zone_id        = var.cloudflare_zone_id
  hostname       = var.vaultwarden_hostname
  origin_service = "http://bitwarden:80"
  tunnel_name    = "homelab-bitwarden"
}
