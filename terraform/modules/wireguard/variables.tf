variable "env" {
  default     = "prod"
  description = "The name of environment for WireGuard. Used to differentiate multiple deployments"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "clients" {
  type = list(object({
    name        = string
    address     = string # e.g., 10.0.0.2/32
    allowed_ips = list(string)
  }))
}

variable "vpc" {
  type = string
}

variable "subnet_ids" {
  type = any
}

variable "vpc_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}