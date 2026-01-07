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

variable "kube_node_flavor" {
  type    = string
  default = "b3-16"
}

variable "kube_node_count" {
  type    = number
  default = 2
}

# Environment-specific variables (from config/{env}/terraform.tfvars)
variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "Environment must be dev or prod."
  }
}

variable "vlan_id" {
  type = number
}

variable "subnet" {
  type = string
}

variable "subnet_start" {
  type = string
}

variable "subnet_end" {
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

variable "deploy_k8s" {
  type        = bool
  default     = false
  description = "Whether to deploy K8s cluster in this environment"
}
