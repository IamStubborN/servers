output "zone_id" {
  description = "Primary Cloudflare zone ID."
  value       = cloudflare_zone.primary.id
}

output "r2_bucket_names" {
  description = "Managed R2 bucket names."
  value       = { for key, bucket in cloudflare_r2_bucket.buckets : key => bucket.name }
}
