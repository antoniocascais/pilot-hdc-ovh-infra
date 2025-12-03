resource "ovh_cloud_project_gateway" "this" {
  for_each     = local.environments
  service_name = var.ovh_project_id
  name         = "gw-s-hdc-${each.key}"
  model        = "s"
  region       = var.region
  network_id   = ovh_cloud_project_network_private.this[each.key].regions_openstack_ids[var.region]
  subnet_id    = ovh_cloud_project_network_private_subnet.this[each.key].id

  lifecycle {
    ignore_changes = [network_id, subnet_id]
  }
}
