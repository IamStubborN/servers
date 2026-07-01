variable "region" {
  description = "OCI region for the runner VM."
  type        = string
  sensitive   = true
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID used by the provider."
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCI user OCID used by the provider API key."
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint for the OCI API signing key."
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Local path to the OCI API signing private key."
  type        = string
  sensitive   = true
}

variable "compartment_ocid" {
  description = "Compartment that owns the runner VM."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key installed on the runner VM."
  type        = string
  sensitive   = true
}
