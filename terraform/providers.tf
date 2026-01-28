terraform {
  required_version = ">= 1.5"

  backend "s3" {} # Config via -backend-config

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "2.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

# Dummy values when deploy_k8s=false - provider won't be used (all k8s resources have count=0)
provider "kubernetes" {
  host                   = var.deploy_k8s ? ovh_cloud_project_kube.this[0].kubeconfig_attributes[0].host : "https://localhost"
  cluster_ca_certificate = var.deploy_k8s ? base64decode(ovh_cloud_project_kube.this[0].kubeconfig_attributes[0].cluster_ca_certificate) : ""
  client_certificate     = var.deploy_k8s ? base64decode(ovh_cloud_project_kube.this[0].kubeconfig_attributes[0].client_certificate) : ""
  client_key             = var.deploy_k8s ? base64decode(ovh_cloud_project_kube.this[0].kubeconfig_attributes[0].client_key) : ""
}
