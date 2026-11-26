locals {
  name         = "rakeem-prod"
  cluster_name = "rakeem-prod-eks"
}

# Identity Center roles in the prod account
data "aws_iam_roles" "sso_admin" {
  name_regex  = "AWSReservedSSO_AdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "sso_readonly" {
  name_regex  = "AWSReservedSSO_ReadOnlyAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

# 1. Network - resilient: one NAT per AZ
module "network" {
  source = "../../modules/network"

  name         = local.name
  cluster_name = local.cluster_name

  vpc_cidr        = "10.30.0.0/16" # no overlap with dev (10.20.0.0/16)
  az_count        = 2
  private_subnets = ["10.30.0.0/19", "10.30.32.0/19"]
  public_subnets  = ["10.30.64.0/24", "10.30.65.0/24"]

  single_nat_gateway = false # prod: survive an AZ failure
}

# 2. No ECR here - prod PULLS images from the dev registry (build once, promote everywhere)

# 3. Kubernetes cluster - stable capacity, read-only by default for humans
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  log_retention_days = 30 # prod: longer audit trail

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  cluster_admin_principal_arns = tolist(data.aws_iam_roles.sso_admin.arns)
  cluster_view_principal_arns  = tolist(data.aws_iam_roles.sso_readonly.arns)

  node_capacity_type  = "ON_DEMAND" # prod: no Spot interruptions
  node_instance_types = ["t3.large"]
  node_min_size       = 3
  node_desired_size   = 3
  node_max_size       = 6
}