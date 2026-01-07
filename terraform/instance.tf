resource "ovh_cloud_project_instance" "nginx" {
  service_name   = var.ovh_project_id
  region         = var.region
  billing_period = "hourly"
  name           = "nginx-${var.env}"

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
        id        = ovh_cloud_project_network_private.this.regions_openstack_ids[var.region]
        subnet_id = ovh_cloud_project_network_private_subnet.this.id
      }
      gateway {
        id = ovh_cloud_project_gateway.this.id
      }
      dynamic "floating_ip" {
        for_each = local.floating_ip_id != "" ? [1] : []
        content {
          id = local.floating_ip_id
        }
      }
    }
  }
}

output "nginx_addresses" {
  value = ovh_cloud_project_instance.nginx.addresses
}
