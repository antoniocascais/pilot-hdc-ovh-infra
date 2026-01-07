resource "ovh_cloud_project_gateway" "this" {
  service_name = var.ovh_project_id
  name         = "gw-s-hdc-${var.env}"
  model        = "s"
  region       = var.region
  network_id   = ovh_cloud_project_network_private.this.regions_openstack_ids[var.region]
  subnet_id    = ovh_cloud_project_network_private_subnet.this.id

  lifecycle {
    ignore_changes = [network_id, subnet_id]
  }
}
