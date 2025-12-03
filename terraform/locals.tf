locals {
  environments = {
    dev = {
      vlan_id        = 100
      subnet         = "10.0.0.0/24"
      subnet_start   = "10.0.0.2"
      subnet_end     = "10.0.0.254"
      floating_ip_id = var.floating_ip_id_dev
    }
    prod = {
      vlan_id        = 200
      subnet         = "10.0.1.0/24"
      subnet_start   = "10.0.1.2"
      subnet_end     = "10.0.1.254"
      floating_ip_id = var.floating_ip_id_prod
    }
  }
}
