resource "ovh_cloud_project_network_private" "this" {
  for_each     = local.environments
  service_name = var.ovh_project_id
  name         = "hdc-${each.key}"
  regions      = [var.region]
  vlan_id      = each.value.vlan_id
}

resource "ovh_cloud_project_network_private_subnet" "this" {
  for_each     = local.environments
  service_name = var.ovh_project_id
  network_id   = ovh_cloud_project_network_private.this[each.key].id
  region       = var.region
  start        = each.value.subnet_start
  end          = each.value.subnet_end
  network      = each.value.subnet
  dhcp         = true
  no_gateway   = false
}
