resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_config_map" "coming_soon" {
  metadata {
    name      = "coming-soon-html"
    namespace = kubernetes_namespace.test.metadata[0].name
  }

  data = {
    "index.html" = <<-EOF
      <!DOCTYPE html>
      <html>
      <head><title>HDC - Coming Soon</title></head>
      <body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;">
        <h1>Coming Soon</h1>
      </body>
      </html>
    EOF
  }
}

resource "kubernetes_deployment" "coming_soon" {
  metadata {
    name      = "coming-soon"
    namespace = kubernetes_namespace.test.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "coming-soon" }
    }
    template {
      metadata {
        labels = { app = "coming-soon" }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.coming_soon.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "coming_soon" {
  metadata {
    name      = "coming-soon"
    namespace = kubernetes_namespace.test.metadata[0].name
  }

  spec {
    selector = { app = "coming-soon" }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "coming_soon" {
  metadata {
    name      = "coming-soon"
    namespace = kubernetes_namespace.test.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["dev.hdc.ebrains.eu"]
      secret_name = "coming-soon-tls"
    }

    rule {
      host = "dev.hdc.ebrains.eu"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.coming_soon.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
