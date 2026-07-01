output "id" {
  description = "OCI instance OCID."
  value       = oci_core_instance.this.id
  sensitive   = true
}

output "public_ip" {
  description = "Instance public IP."
  value       = oci_core_instance.this.public_ip
  sensitive   = true
}
