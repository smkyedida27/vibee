output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.api.cluster_name
}

output "ecs_service_name" {
  value = module.api.service_name
}

output "ecs_task_family" {
  value = module.api.task_family
}

output "alb_dns_name" {
  description = "Point the API hostname (CNAME/alias) at this"
  value       = module.api.alb_dns_name
}

output "assets_cdn_domain" {
  value = module.assets.cdn_domain_name
}

output "db_endpoint" {
  value = module.db.endpoint
}

output "alerts_topic_arn" {
  value = module.monitoring.sns_topic_arn
}
