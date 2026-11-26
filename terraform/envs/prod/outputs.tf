output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.network.vpc_id
}