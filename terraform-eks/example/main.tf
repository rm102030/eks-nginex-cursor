provider "aws" {
  region = "us-east-1"
}

provider "null" {}

# VPC and Subnet configuration
module "vpc" {
  source = "../../../module"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# EKS Cluster
module "eks" {
  source = "../../../module"

  cluster_name    = "example-eks-cluster"
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      disk_size      = 20

      labels = {
        Environment = "production"
        NodeGroup   = "general"
      }

      taints = []

      tags = {
        Environment = "production"
        NodeGroup   = "general"
      }
    }
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# Deploy NGINX after cluster is ready
resource "kubernetes_namespace" "frontend" {
  metadata {
    name = "frontend"
  }
  depends_on = [module.eks]
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.frontend.metadata[0].name
  }

  spec {
    replicas = 3

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
          image = "nginx:1.25"
          name  = "nginx"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
  depends_on = [module.eks]
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.frontend.metadata[0].name
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
  }
  depends_on = [module.eks]
} 