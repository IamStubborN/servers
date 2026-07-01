locals {
  dns_records = coalesce(var.dns_records, {
    root = {
      name    = var.zone_name
      content = var.server_ip
      type    = "A"
      proxied = true
      ttl     = 1
    }
    www = {
      name    = "www"
      content = var.zone_name
      type    = "CNAME"
      proxied = true
      ttl     = 1
    }
  })

  zone_settings = {
    always_use_https         = var.always_use_https
    automatic_https_rewrites = var.automatic_https_rewrites
    min_tls_version          = var.min_tls_version
    ssl                      = var.ssl_mode
  }
}

resource "cloudflare_zone" "primary" {
  account = {
    id = var.account_id
  }

  name = var.zone_name
}

resource "cloudflare_zone_setting" "primary" {
  for_each = local.zone_settings

  setting_id = each.key
  value      = each.value
  zone_id    = cloudflare_zone.primary.id
}

resource "cloudflare_dns_record" "records" {
  for_each = local.dns_records

  name    = each.value.name
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
  type    = each.value.type
  zone_id = cloudflare_zone.primary.id
}

resource "cloudflare_dns_record" "acme_challenge_local" {
  count = var.acme_challenge_local_txt == "" ? 0 : 1

  name    = "_acme-challenge.local"
  content = var.acme_challenge_local_txt
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.primary.id
}

resource "cloudflare_r2_bucket" "buckets" {
  for_each = var.r2_buckets

  account_id = var.account_id
  name       = each.value.name
  location   = each.value.location
}
