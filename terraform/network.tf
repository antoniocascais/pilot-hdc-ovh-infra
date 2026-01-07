resource "ovh_cloud_project_network_private" "this" {
  service_name = var.ovh_project_id
  name         = "hdc-${var.env}"
  regions      = [var.region]
  vlan_id      = var.vlan_id
}

resource "ovh_cloud_project_network_private_subnet" "this" {
  service_name = var.ovh_project_id
  network_id   = ovh_cloud_project_network_private.this.id
  region       = var.region
  start        = var.subnet_start
  end          = var.subnet_end
  network      = var.subnet
  dhcp         = true
  no_gateway   = false
}
