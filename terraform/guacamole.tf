resource "ovh_cloud_project_instance" "guacamole" {
  for_each       = var.deploy_guacamole ? toset(var.workspace_projects) : toset([])
  service_name   = var.ovh_project_id
  region         = var.region
  billing_period = "hourly"
  name           = "guacamole-${each.value}-${var.env}"

  boot_from {
    image_id = var.guacamole_image_id
  }

  flavor {
    flavor_id = var.guacamole_flavor_id
  }

  ssh_key {
    name = var.ssh_key_name
  }

  # Ubuntu 22.04 uses standalone sshd.service, not ssh.socket
  user_data = <<-EOF
    #!/bin/bash
    systemctl enable --now ssh
  EOF

  network {
    private {
      network {
        id        = ovh_cloud_project_network_private.this.regions_openstack_ids[var.region]
        subnet_id = ovh_cloud_project_network_private_subnet.this.id
      }
      gateway {
        id = ovh_cloud_project_gateway.this.id
      }
    }
  }
}

resource "ovh_cloud_project_volume" "guacamole" {
  for_each     = var.deploy_guacamole ? toset(var.workspace_projects) : toset([])
  service_name = var.ovh_project_id
  region_name  = var.region
  name         = "guacamole-data-${each.value}-${var.env}"
  description  = "Guacamole data volume (Docker + homes) for ${each.value} ${var.env}"
  size         = var.guacamole_volume_size
  type         = "classic"
}

output "guacamole_addresses" {
  value = {
    for project, instance in ovh_cloud_project_instance.guacamole :
    project => instance.addresses
  }
}

output "guacamole_volume_ids" {
  value = {
    for project, volume in ovh_cloud_project_volume.guacamole :
    project => volume.id
  }
}
