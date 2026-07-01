resource "hcloud_server" "this" {
  name        = var.name
  image       = var.image
  server_type = var.server_type
  location    = var.location

  backups      = var.backups
  firewall_ids = var.firewall_ids
  labels       = var.labels
  ssh_keys     = var.ssh_keys
  user_data    = var.user_data

  public_net {
    ipv4_enabled = var.ipv4_enabled
    ipv6_enabled = var.ipv6_enabled
  }
}
