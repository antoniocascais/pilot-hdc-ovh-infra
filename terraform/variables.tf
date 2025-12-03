variable "ovh_application_key" {
  type      = string
  sensitive = true
}

variable "ovh_application_secret" {
  type      = string
  sensitive = true
}

variable "ovh_consumer_key" {
  type      = string
  sensitive = true
}

variable "ovh_project_id" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type = string
}

variable "region" {
  type    = string
  default = "DE1"
}

variable "instance_flavor_id" {
  type = string
}

variable "instance_image_id" {
  type = string
}

variable "floating_ip_id_dev" {
  type        = string
  default     = ""
  description = "Floating IP ID for dev nginx (create in OVH UI after network exists)"
}

variable "floating_ip_id_prod" {
  type        = string
  default     = ""
  description = "Floating IP ID for prod nginx (create in OVH UI after network exists)"
}
