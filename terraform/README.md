# Terraform Configuration for African Griot Blog

This directory contains Terraform configuration for deploying the app to AWS ECS on Fargate.

## What It Creates

- Amazon ECR repository for the Docker image
- Amazon ECS cluster, task definition, and Fargate service
- Application Load Balancer for public web access
- IAM role so ECS tasks can pull from ECR and write logs
- CloudWatch log group for container logs
- VPC, public subnets, route table, and security groups
- Optional Amazon S3 bucket for future upload persistence

## Quick Start

1. Configure AWS credentials locally:

```bash
aws configure
```

2. Copy the example variables file if you want to customize values:

```bash
cd terraform
copy terraform.tfvars.example terraform.tfvars
```

3. Initialize Terraform:

```bash
terraform init
```

4. Review the plan:

```bash
terraform plan
```

5. Create the ECR repository first:

```bash
terraform apply -target=aws_ecr_repository.africangriot
```

6. Push your Docker image to the ECR repository Terraform creates:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker build -t africangriot .
docker tag africangriot:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/africangriot:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/africangriot:latest
```

7. Re-run Terraform to create the rest of the ECS and load balancer resources:

```bash
terraform apply
```

8. After the service stabilizes, use `terraform output service_url` to get the public URL.

## Defaults

- Region: `us-east-1`
- ECS service name: `africangriot`
- Container port: `8080`
- CPU: `512`
- Memory: `1024`
- Desired tasks: `1`
- Min tasks: `1`
- Max tasks: `1`
- Health check path: `/health`

## Files

```text
terraform/
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- terraform.tfvars.example
`-- README.md
```

## Notes

- The app still stores posts in memory, so restarts lose data.
- Uploads still go to the local container filesystem today, so they are ephemeral.
- The S3 bucket is optional and only created when `create_uploads_bucket = true`.
- Pushing a new image to ECR does not redeploy ECS by itself; update the tag or run another deployment after pushing.

## Useful Commands

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```
