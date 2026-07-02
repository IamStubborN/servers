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

variable "enable_symphony_bootstrap" {
  description = "Install the upstream Symphony runtime bootstrap on the instance."
  type        = bool
  default     = true
}

variable "hostname_label" {
  description = "Primary VNIC hostname label."
  type        = string
  default     = "runner"
}

variable "agent_flow_ref" {
  description = "Git ref used for the agent-flow checkout."
  type        = string
  default     = "main"
}

variable "agent_flow_repo_url" {
  description = "Git URL for the agent-flow checkout."
  type        = string
  default     = "git@github.com:AttentionWorld/agent-flow.git"
}

variable "agent_flow_root" {
  description = "Absolute path for the agent-flow checkout."
  type        = string
  default     = "/opt/agent-flow"
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

variable "symphony_dashboard_port" {
  description = "Loopback dashboard port for upstream Symphony."
  type        = number
  default     = 4097
}

variable "symphony_ref" {
  description = "Git ref used for the upstream Symphony checkout."
  type        = string
  default     = "main"
}

variable "symphony_repo_url" {
  description = "Git URL for the upstream Symphony checkout."
  type        = string
  default     = "https://github.com/openai/symphony.git"
}

variable "symphony_root" {
  description = "Absolute path for the upstream Symphony checkout."
  type        = string
  default     = "/opt/symphony"
}

variable "symphony_service_user" {
  description = "Linux user that owns and runs the Symphony service."
  type        = string
  default     = "symphony"
}

variable "symphony_state_root" {
  description = "Runtime home for the Symphony service user."
  type        = string
  default     = "/var/lib/symphony"
}

variable "symphony_workspace_root" {
  description = "Root directory for per-issue Symphony workspaces."
  type        = string
  default     = "/var/lib/symphony/workspaces"
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
