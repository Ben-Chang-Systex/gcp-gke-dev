terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# 取得 GCP 存取 Token
data "google_client_config" "default" {}

# 讀取現有的 GKE 叢集資訊
data "google_container_cluster" "my_cluster" {
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id
}

# 設定 Kubernetes Provider
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

# 部署 Nginx
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-deployment"
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# 建立 LoadBalancer 服務
resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "nginx-service"
    annotations = {
      "networking.gke.io/load-balancer-type" = "External"
    }
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
    # 如果你只有名稱，建議透過 data "google_compute_address" 取得 IP 位址
    load_balancer_ip = data.google_compute_address.static_ip.address
  }
}

# 輸出 LoadBalancer IP
output "nginx_ip" {
  value = kubernetes_service.nginx_service.status[0].load_balancer[0].ingress[0].ip
}