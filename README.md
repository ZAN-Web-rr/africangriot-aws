# African Griot Blog

A modern blogging platform built with Express.js, EJS, and Multer. Inspired by traditional African griots, this application lets users create, view, and manage blog posts with image uploads.

## Features

- Create blog posts with titles, content, and images
- Image upload support with Multer
- Responsive design
- Delete posts functionality
- Docker support for deployment
- Terraform config for AWS infrastructure

## Technology Stack

- **Backend**: Node.js, Express.js
- **Frontend**: EJS
- **File Upload**: Multer
- **Styling**: Custom CSS
- **Deployment**: Docker, AWS ECS Fargate
- **Infrastructure as Code**: Terraform

## Prerequisites

- Node.js 18 or higher
- npm
- Docker
- Terraform 1.0 or higher
- AWS CLI configured with credentials

## Local Development

1. Install dependencies:

```bash
npm install
```

2. Start the development server:

```bash
npm run dev
```

3. Open:

```text
http://localhost:8080
```

## Docker

Build the image:

```bash
docker build -t africangriot .
```

Run it locally:

```bash
docker run -p 8080:8080 africangriot
```

Health check endpoint:

```text
GET /health
```

## AWS Deployment

This repo is now set up for AWS using:

- **Amazon ECR** for the Docker image
- **Amazon ECS on Fargate** for the web service
- **Application Load Balancer** for public HTTP access
- **Amazon S3** as an optional bucket for future persistent uploads

### Quick Deploy Flow

1. Build the image:

```bash
docker build -t africangriot .
```

2. Create the ECR repository first:

```bash
cd terraform
terraform init
terraform apply -target=aws_ecr_repository.africangriot
```

3. Authenticate Docker to ECR, tag the image, and push it:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag africangriot:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/africangriot:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/africangriot:latest
```

4. Run Terraform again to create the rest of the Fargate infrastructure:

```bash
terraform apply
```

5. Open the load balancer URL from:

```bash
terraform output service_url
```

For more detail, see [terraform/README.md](terraform/README.md).

## Project Structure

```text
africangriot/
|-- public/
|   `-- css/
|       `-- style.css
|-- views/
|   |-- home.ejs
|   |-- all-posts.ejs
|   |-- post-detail.ejs
|   |-- about.ejs
|   `-- contact.ejs
|-- terraform/
|   |-- main.tf
|   |-- variables.tf
|   |-- outputs.tf
|   |-- terraform.tfvars.example
|   `-- README.md
|-- server.js
|-- package.json
|-- Dockerfile
`-- README.md
```

## Environment Variables

- `PORT`: server port, default `8080`
- `NODE_ENV`: runtime environment
- `MAX_FILE_SIZE`: upload size limit in bytes, default `5242880`

## Notes

- Posts are stored in memory and will be lost on restart.
- Uploaded files are written to the local `uploads/` directory and are also ephemeral in container environments.
- Pushing a new Docker image to ECR does not automatically refresh ECS tasks; run a new deployment after updating the image tag.
- For production persistence, add a database for posts and move image storage to S3.

## Pre-Deploy Checklist

- Run `npm install` and confirm dependencies install cleanly.
- Run `node --check server.js`.
- Run `docker build -t africangriot .`.
- In `terraform/`, run `terraform fmt`.
- In `terraform/`, run `terraform validate`.
- In `terraform/`, review `terraform.tfvars` values for region, subnet CIDRs, task size, and service name.
- Confirm your AWS credentials can manage ECR, ECS, ALB, IAM, CloudWatch, and VPC resources.
- Create the ECR repository with `terraform apply -target=aws_ecr_repository.africangriot`.
- Push the Docker image to the ECR repository.
- Run `terraform apply` to create or update the Fargate service.
- After deployment, open `terraform output service_url` and verify `GET /health` returns `200`.

## License

Apache-2.0
