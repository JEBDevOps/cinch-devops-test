variable "project_name" {
  type        = string
  default     = "cinch-test"
  description = "The name of the project."
}

variable "github_org" {
  type        = string
  default     = "JEBDevOps"
  description = "The GitHub organization where the repository is located."
}

variable "github_repo" {
  type        = string
  default     = "react-ts-learning"
  description = "The name of the GitHub repository."
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID."
}

variable "ecr_repository_name" {
  type        = string
  default     = "react-ts-app"
  description = "The name of the ECR repository."
}

variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "The AWS region to deploy the resources in."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "The CIDR block for the VPC."
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "The CIDR block for the public subnet."
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "The CIDR block for the private subnet."
}

variable "availability_zone" {
  type        = string
  default     = "ap-southeast-1a"
  description = "The availability zone to deploy the resources in."
}

variable "key_name" {
  description = "The name of the key pair to use for the instances"
  type        = string
  default     = "cinch-test-key"
}

variable "grafana_prometheus_endpoint" {
  description = "Grafana Cloud Prometheus remote write endpoint"
  type        = string
  sensitive   = true
}

variable "grafana_prometheus_user_id" {
  description = "Grafana Cloud Prometheus user ID"
  type        = string
  sensitive   = true
}

variable "grafana_api_key" {
  description = "Grafana Cloud API Key"
  type        = string
  sensitive   = true
}

variable "create_nat_instance" {
  type        = bool
  default     = true
  description = "Whether to create a NAT instance."
}

variable "nat_instance_ami_id" {
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" # amazon linux 2023
  description = "The AMI ID for the NAT instance."
}

variable "default_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The default EC2 instance type."
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "" # IP Address of DevOps
  description = "The CIDR block allowed to SSH into the instances."
}

variable "bastion_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The EC2 instance type for the bastion host."
}

variable "bastion_instance_ami_id" {
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" # amazon linux 2
  description = "The AMI ID for the bastion host."
}

variable "bucket_name" {
  type        = string
  default     = "cinch-test-log"
  description = "The name of the S3 bucket for logging."
}

variable "app_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The EC2 instance type for the application instance."
}

variable "app_instance_ami_id" {
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  description = "The AMI ID for the application instance."
}

variable "enable_wireguard" {
  description = "If set to true, the WireGuard server and related resources will be created."
  type        = bool
  default     = false
}
