# Managed K8s cluster (conditional on deploy_k8s)
resource "ovh_cloud_project_kube" "this" {
  count = var.deploy_k8s ? 1 : 0

  service_name = var.ovh_project_id
  name         = "hdc-${var.env}"
  region       = var.region

  private_network_id = tolist(
    ovh_cloud_project_network_private.this.regions_attributes
  )[0].openstackid

  nodes_subnet_id = ovh_cloud_project_network_private_subnet.this.id

  private_network_configuration {
    # Empty gateway = nodes get public IPs for egress (multiple egress IPs)
    # Set to router IP for single egress IP (useful for external service whitelisting)
    default_vrack_gateway              = ""
    private_network_routing_as_default = true
  }

  depends_on = [ovh_cloud_project_gateway.this]

  timeouts {
    create = "20m"
  }
}

# Node pool
resource "ovh_cloud_project_kube_nodepool" "default" {
  count = var.deploy_k8s ? 1 : 0

  service_name  = var.ovh_project_id
  kube_id       = ovh_cloud_project_kube.this[0].id
  name          = "default-pool"
  flavor_name   = var.kube_node_flavor
  desired_nodes = var.kube_node_count

  timeouts {
    create = "20m"
  }
}

output "kube_cluster_id" {
  value = var.deploy_k8s ? ovh_cloud_project_kube.this[0].id : null
}

output "kubeconfig" {
  value     = var.deploy_k8s ? ovh_cloud_project_kube.this[0].kubeconfig : null
  sensitive = true
}
