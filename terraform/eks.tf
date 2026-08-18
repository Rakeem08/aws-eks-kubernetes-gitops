module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_private_access = true
  endpoint_public_access  = true

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  upgrade_policy = {
    support_type = "STANDARD"
  }

  enabled_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

  cloudwatch_log_group_retention_in_days = 7

  addons = {
    coredns = {}

    eks-pod-identity-agent = {
      before_compute = true
    }

    kube-proxy = {}

    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    application_nodes = {
      name = "${var.project_name}-nodes"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      disk_size = 30

      node_repair_config = {
        enabled = true
      }

      labels = {
        role = "application"
      }

      autoscaling_group_tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }
}