output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS nodes)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers)"
  value       = module.vpc.public_subnets
}

output "azs" {
  description = "Availability zones in use"
  value       = local.azs
}