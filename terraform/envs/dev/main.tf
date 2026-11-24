locals {
  name         = "rakeem-dev"
  cluster_name = "rakeem-dev-eks"
}

# Look up the Identity Center admin role in this account (created by your permission set)
data "aws_iam_roles" "sso_admin" {
  name_regex  = "AWSReservedSSO_AdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

# 1. Network
module "network" {
  source = "../../modules/network"

  name         = local.name
  cluster_name = local.cluster_name

  vpc_cidr        = "10.20.0.0/16"
  az_count        = 2
  private_subnets = ["10.20.0.0/19", "10.20.32.0/19"]
  public_subnets  = ["10.20.64.0/24", "10.20.65.0/24"]

  single_nat_gateway = true # dev: one NAT to save cost
}

# 2. Container registry (dev acts as the registry account)
module "ecr" {
  source = "../../modules/ecr"

  name             = "rakeem-app"
  force_delete     = true # dev only: allows destroy with images inside
  pull_account_ids = var.ecr_pull_account_ids
}

# 3. Kubernetes cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  cluster_admin_principal_arns = tolist(data.aws_iam_roles.sso_admin.arns)

  node_capacity_type  = "SPOT" # dev: cheaper, can be interrupted
  node_instance_types = ["t3.medium", "t3a.medium"]
  node_min_size       = 2
  node_desired_size   = 2
  node_max_size       = 4
}

# 4. IAM role for the AWS Load Balancer Controller (Pod Identity - no keys)
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "${local.cluster_name}-aws-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

# 5. GitHub Actions -> AWS with OIDC (no stored keys)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Token must be meant for AWS
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Q2: only THIS repo, only THESE branches
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Rakeem08/aws-eks-kubernetes-gitops:ref:refs/heads/phase-1-foundations",
        "repo:Rakeem08/aws-eks-kubernetes-gitops:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ecr" {
  name               = "${local.name}-github-actions-ecr"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ecr_push" {
  # ECR login can't be scoped to a repo (AWS limitation)
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Q3: push to ONE repo only
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
    ]
    resources = [module.ecr.repository_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "ecr-push-rakeem-app"
  role   = aws_iam_role.github_actions_ecr.id
  policy = data.aws_iam_policy_document.ecr_push.json
}