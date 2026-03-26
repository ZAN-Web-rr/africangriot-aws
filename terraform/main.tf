# Terraform configuration for African Griot Blog on AWS Fargate

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote state storage in S3
  # backend "s3" {
  #   bucket = "africangriot-terraform-state"
  #   key    = "terraform/state.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix    = var.service_name
  container_name = var.service_name

  common_tags = {
    Name        = var.service_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecr_repository" "africangriot" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_vpc" "africangriot" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "africangriot" {
  vpc_id = aws_vpc.africangriot.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = {
    for index, cidr in var.public_subnet_cidrs : index => cidr
  }

  vpc_id                  = aws_vpc.africangriot.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${tonumber(each.key) + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.africangriot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.africangriot.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound web traffic to the load balancer"
  vpc_id      = aws_vpc.africangriot.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "service" {
  name        = "${local.name_prefix}-service-sg"
  description = "Allow load balancer traffic to the ECS service"
  vpc_id      = aws_vpc.africangriot.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service-sg"
  })
}

resource "aws_lb" "africangriot" {
  name               = substr("${local.name_prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "africangriot" {
  name        = substr("${local.name_prefix}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.africangriot.id

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.africangriot.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.africangriot.arn
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "africangriot" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = var.log_retention_in_days

  tags = local.common_tags
}

resource "aws_ecs_cluster" "africangriot" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "africangriot" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${aws_ecr_repository.africangriot.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "MAX_FILE_SIZE"
          value = tostring(var.max_file_size)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.africangriot.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.service_name
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "africangriot" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.africangriot.id
  task_definition = aws_ecs_task_definition.africangriot.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    assign_public_ip = true
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.africangriot.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.max_tasks
  min_capacity       = var.min_tasks
  resource_id        = "service/${aws_ecs_cluster.africangriot.name}/${aws_ecs_service.africangriot.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.africangriot]
}

resource "aws_appautoscaling_policy" "ecs_service_cpu" {
  name               = "${local.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_s3_bucket" "uploads" {
  count = var.create_uploads_bucket ? 1 : 0

  bucket        = var.uploads_bucket_name
  force_destroy = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-uploads"
  })
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  count = var.create_uploads_bucket ? 1 : 0

  bucket = aws_s3_bucket.uploads[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  count = var.create_uploads_bucket ? 1 : 0

  bucket = aws_s3_bucket.uploads[0].id

  versioning_configuration {
    status = "Enabled"
  }
}
