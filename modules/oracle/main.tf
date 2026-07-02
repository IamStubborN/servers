data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "this" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

locals {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_index].name
  install_runtime     = file("${path.module}/../../scripts/install_symphony_runtime.sh")
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    agent_flow_repo_url = var.agent_flow_repo_url
    agent_flow_root     = var.agent_flow_root
    agent_flow_ref      = var.agent_flow_ref
    dashboard_port      = var.symphony_dashboard_port
    install_runtime     = local.install_runtime
    service_user        = var.symphony_service_user
    state_root          = var.symphony_state_root
    symphony_repo_url   = var.symphony_repo_url
    symphony_ref        = var.symphony_ref
    symphony_root       = var.symphony_root
    workspace_root      = var.symphony_workspace_root
  })
  image_id  = data.oci_core_images.this.images[0].id
  user_data = base64encode(local.cloud_init)
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = "${var.name}-vcn"
  dns_label      = var.vcn_dns_label
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name}-igw"
  enabled        = true
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name}-public-rt"
  vcn_id         = oci_core_vcn.this.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name}-public-sl"
  vcn_id         = oci_core_vcn.this.id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_allowed_cidr

    tcp_options {
      max = 22
      min = 22
    }
  }
}

resource "oci_core_subnet" "public" {
  cidr_block                 = var.subnet_cidr_block
  compartment_id             = var.compartment_ocid
  display_name               = "${var.name}-public-subnet"
  dns_label                  = var.subnet_dns_label
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  vcn_id                     = oci_core_vcn.this.id
}

resource "oci_core_instance" "this" {
  availability_domain  = local.availability_domain
  compartment_id       = var.compartment_ocid
  display_name         = var.name
  preserve_boot_volume = false
  shape                = var.shape
  state                = "RUNNING"

  create_vnic_details {
    assign_public_ip = true
    hostname_label   = var.hostname_label
    subnet_id        = oci_core_subnet.public.id
  }

  metadata = merge(
    {
      ssh_authorized_keys = var.ssh_public_key
    },
    var.enable_symphony_bootstrap ? {
      user_data = local.user_data
    } : {}
  )

  shape_config {
    memory_in_gbs = var.memory_in_gbs
    ocpus         = var.ocpus
  }

  source_details {
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
    source_id               = local.image_id
    source_type             = "image"
  }

  lifecycle {
    ignore_changes = [
      metadata["user_data"],
    ]
  }
}
