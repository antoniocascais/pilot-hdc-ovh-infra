resource "ovh_cloud_project_instance" "nginx" {
  for_each       = local.environments
  service_name   = var.ovh_project_id
  region         = var.region
  billing_period = "hourly"
  name           = "nginx-${each.key}"

  boot_from {
    image_id = var.instance_image_id
  }

  flavor {
    flavor_id = var.instance_flavor_id
  }

  ssh_key {
    name = var.ssh_key_name
  }

  network {
    private {
      network {
        id        = ovh_cloud_project_network_private.this[each.key].regions_openstack_ids[var.region]
        subnet_id = ovh_cloud_project_network_private_subnet.this[each.key].id
      }
      gateway {
        id = ovh_cloud_project_gateway.this[each.key].id
      }
      dynamic "floating_ip" {
        for_each = each.value.floating_ip_id != "" ? [1] : []
        content {
          id = each.value.floating_ip_id
        }
      }
    }
  }
}

output "nginx_addresses" {
  value = { for k, v in ovh_cloud_project_instance.nginx : k => v.addresses }
}
