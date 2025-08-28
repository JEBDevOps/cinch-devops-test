variable "project_name" {
  type    = string
  default = "cinch-test"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "availability_zone" {
  type    = string
  default = "ap-southeast-1a"
}

variable "key_name" {
  type    = string
  default = "cinch-test-key"
}

variable "create_nat_instance" {
  type    = bool
  default = true
}

variable "nat_instance_ami_id" {
  type    = string
  default = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" # amazon linux 2023
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "" # IP Address of DevOps
}

variable "bastion_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "bastion_instance_ami_id" {
  type    = string
  default = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" # amazon linux 2
}

variable "bucket_name" {
  type    = string
  default = "cinch-test-log"
}

variable "app_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "app_instance_ami_id" {
  type    = string
  default = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}