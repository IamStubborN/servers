output "id" {
  description = "OCI instance OCID."
  value       = try(oci_core_instance.this[0].id, null)
  sensitive   = true
}

output "public_ip" {
  description = "Instance public IP."
  value       = try(oci_core_instance.this[0].public_ip, null)
  sensitive   = true
}
