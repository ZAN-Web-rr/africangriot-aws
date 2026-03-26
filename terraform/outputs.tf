# Output values after Terraform apply

output "service_url" {
  description = "Public URL of the deployed load balancer"
  value       = "http://${aws_lb.africangriot.dns_name}"
}

output "load_balancer_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.africangriot.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.africangriot.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.africangriot.name
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.africangriot.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.africangriot.repository_url
}

output "uploads_bucket_name" {
  description = "Name of the optional S3 bucket for future uploads"
  value       = try(aws_s3_bucket.uploads[0].bucket, null)
}

output "aws_account_id" {
  description = "AWS account ID used for deployment"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS deployment region"
  value       = var.aws_region
}
