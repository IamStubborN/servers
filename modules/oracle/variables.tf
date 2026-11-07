variable "compartment_ocid" {
  description = "Compartment that owns the Oracle resources."
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Base name for Oracle resources."
  type        = string
  default     = "runner"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to reach SSH."
  type        = string
  default     = "0.0.0.0/0"
}

variable "subnet_cidr_block" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_dns_label" {
  description = "Public subnet DNS label."
  type        = string
  default     = "public"
}

variable "vcn_cidr_blocks" {
  description = "VCN CIDR blocks."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vcn_dns_label" {
  description = "VCN DNS label."
  type        = string
  default     = "servers"
}
