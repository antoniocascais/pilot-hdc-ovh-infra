locals {
  floating_ip_id = var.env == "dev" ? var.floating_ip_id_dev : var.floating_ip_id_prod
}
