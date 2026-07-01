module "oracle" {
  source = "./modules/oracle"

  compartment_ocid = var.compartment_ocid
  ssh_public_key   = var.ssh_public_key
}
