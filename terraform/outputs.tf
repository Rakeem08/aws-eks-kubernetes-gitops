output "aws_region" {
  description = "AWS region containing the project resources"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the project VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the Application Load Balancer"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS worker nodes"
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "Name of the Amazon EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Address of the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "Amazon ECR address used for Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "kubectl_config_command" {
  description = "Command used to connect kubectl to the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}