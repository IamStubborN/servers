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
