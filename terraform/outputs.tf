output "bastion_id" {
  description = "The ID of the bastion host instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "bastion_sg_id" {
  description = "The ID of the bastion host's security group"
  value       = aws_security_group.bastion.id
}

output "logs_bucket_name" {
  description = "The name of the S3 bucket for logs"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "The ARN of the S3 bucket for logs"
  value       = aws_s3_bucket.logs.arn
}

output "app_instance_id" {
  description = "The ID of the app instance"
  value       = aws_instance.app.id
}

output "app_private_ip" {
  description = "The private IP address of the app instance"
  value       = aws_instance.app.private_ip
}

output "app_security_group_id" {
  description = "The ID of the app's security group"
  value       = aws_security_group.app.id
}

output "wireguard_client_config" {
  description = "WireGuard client configuration for the first client. Save this output to a .conf file."
  value       = var.enable_wireguard ? try(module.wireguard[0].client_configs[0], "No client configs generated.") : "WireGuard is disabled."
  sensitive   = true
}

output "wireguard_server_ip" {
  description = "Public IP of the WireGuard server."
  value       = var.enable_wireguard ? try(module.wireguard[0].server_public_ip, "N/A") : "WireGuard is disabled."
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "The ARN of the IAM role for GitHub Actions OIDC"
}

output "tailscale_router_instance_id" {
  description = "The ID of the Tailscale router instance."
  value       = var.enable_tailscale ? try(aws_instance.tailscale_router[0].id, "N/A") : "Tailscale is disabled."
}

output "tailscale_router_public_ip" {
  description = "The public IP address of the Tailscale router instance."
  value       = var.enable_tailscale ? try(aws_instance.tailscale_router[0].public_ip, "N/A") : "Tailscale is disabled."
}

output "tailscale_router_private_ip" {
  description = "The private IP address of the Tailscale router instance."
  value       = var.enable_tailscale ? try(aws_instance.tailscale_router[0].private_ip, "N/A") : "Tailscale is disabled."
}

output "tailscale_router_security_group_id" {
  description = "The ID of the Tailscale router's security group."
  value       = var.enable_tailscale ? try(aws_security_group.tailscale[0].id, "N/A") : "Tailscale is disabled."
}
