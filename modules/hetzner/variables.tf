variable "name" {
  description = "Server name."
  type        = string
}

variable "image" {
  description = "Image slug."
  type        = string
}

variable "server_type" {
  description = "Server type."
  type        = string
}

variable "location" {
  description = "Server location."
  type        = string
}

variable "backups" {
  description = "Enable backups."
  type        = bool
  default     = false
}

variable "firewall_ids" {
  description = "Firewall IDs attached to the server."
  type        = list(number)
  default     = []
}

variable "ipv4_enabled" {
  description = "Enable public IPv4."
  type        = bool
  default     = true
}

variable "ipv6_enabled" {
  description = "Enable public IPv6."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the server."
  type        = map(string)
  default     = {}
}

variable "ssh_keys" {
  description = "SSH key names or IDs."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Cloud-init user data."
  type        = string
  default     = null
  sensitive   = true
}
