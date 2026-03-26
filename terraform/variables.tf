# Input variables for African Griot Blog infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment tag"
  type        = string
  default     = "production"
}

variable "service_name" {
  description = "Name used for ECS, ALB, and related resources"
  type        = string
  default     = "africangriot"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "africangriot"
}

variable "image_tag" {
  description = "Docker image tag the ECS task definition should deploy"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of running Fargate tasks"
  type        = number
  default     = 1
}

variable "min_tasks" {
  description = "Minimum number of tasks for ECS service autoscaling"
  type        = number
  default     = 1
}

variable "max_tasks" {
  description = "Maximum number of tasks for ECS service autoscaling"
  type        = number
  default     = 1
}

variable "target_cpu_utilization" {
  description = "Average CPU utilization target for ECS service autoscaling"
  type        = number
  default     = 70
}

variable "health_check_path" {
  description = "HTTP path used by the load balancer health check"
  type        = string
  default     = "/health"
}

variable "max_file_size" {
  description = "Maximum upload size exposed to the container as an environment variable"
  type        = number
  default     = 5242880
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for ECS container logs"
  type        = number
  default     = 7
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for at least two public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Provide at least two public subnet CIDRs for the load balancer."
  }
}

variable "create_uploads_bucket" {
  description = "Whether to create an S3 bucket for future upload persistence"
  type        = bool
  default     = false
}

variable "uploads_bucket_name" {
  description = "Name of the S3 bucket for uploads when create_uploads_bucket is true"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = !var.create_uploads_bucket || (var.uploads_bucket_name != null && length(trim(var.uploads_bucket_name)) > 0)
    error_message = "Set uploads_bucket_name when create_uploads_bucket is true."
  }
}
