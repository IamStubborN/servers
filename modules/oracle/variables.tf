variable "compartment_ocid" {
  description = "Compartment that owns the Oracle resources."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key installed on the instance."
  type        = string
  sensitive   = true
}

variable "availability_domain_index" {
  description = "Zero-based availability domain index."
  type        = number
  default     = 0
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size."
  type        = number
  default     = 50
}

variable "hostname_label" {
  description = "Primary VNIC hostname label."
  type        = string
  default     = "runner"
}

variable "image_operating_system" {
  description = "Operating system used to find the latest platform image."
  type        = string
  default     = "Oracle Linux"
}

variable "image_operating_system_version" {
  description = "Operating system version used to find the latest platform image."
  type        = string
  default     = "9"
}

variable "memory_in_gbs" {
  description = "Memory allocated to the instance."
  type        = number
  default     = 12
}

variable "name" {
  description = "Base name for Oracle resources."
  type        = string
  default     = "runner"
}

variable "ocpus" {
  description = "OCPUs allocated to the instance."
  type        = number
  default     = 2
}

variable "shape" {
  description = "OCI compute shape."
  type        = string
  default     = "VM.Standard.A1.Flex"
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
