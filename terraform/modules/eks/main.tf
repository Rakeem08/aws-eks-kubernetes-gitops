module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  # --- Cluster basics ---
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # --- Who can reach the Kubernetes API ---
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # --- Access & identity ---
  enable_cluster_creator_admin_permissions = false
  enable_irsa                              = false

  # --- Cost: avoid extended-support pricing ---
  upgrade_policy = {
    support_type = "STANDARD"
  }

  # --- Audit logging ---
  enabled_log_types                      = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = var.tags

  # --- Managed add-ons (core cluster software) ---
  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    coredns    = {}
    kube-proxy = {}
  }

  # --- Who can do what inside Kubernetes ---
  access_entries = merge(
    {
      for idx, arn in var.cluster_admin_principal_arns : "admin-${idx}" => {
        principal_arn = arn
        policy_associations = {
          cluster_admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    {
      for idx, arn in var.cluster_view_principal_arns : "view-${idx}" => {
        principal_arn = arn
        policy_associations = {
          view = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }
  )

  # --- Worker nodes ---
  eks_managed_node_groups = {
    application = {
      name = "${var.cluster_name}-nodes"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      disk_size = 30

      # Replace unhealthy nodes automatically
      node_repair_config = {
        enabled = true
      }

      # Roll out node updates gradually, never all at once
      update_config = {
        max_unavailable_percentage = 33
      }

      labels = {
        role          = "application"
        capacity-type = lower(var.node_capacity_type)
      }

      autoscaling_group_tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }
}