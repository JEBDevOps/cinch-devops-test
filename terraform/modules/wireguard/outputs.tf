locals {
  client_configs = [
    for i, client in var.clients :
    templatefile("${path.module}/templates/client.tpl", {
      private_key    = wireguard_asymmetric_key.client_keys[i].private_key
      address        = client.address
      server_pub_key = wireguard_asymmetric_key.wireguard_key.public_key
      server_ip      = aws_eip.wireguard.public_ip
      allowed_ips    = client.allowed_ips
    })
  ]
}

output "wg_public_key" {
  description = "Public WireGuard key"
  value       = wireguard_asymmetric_key.wireguard_key.public_key
}

output "wg_private_key" {
  description = "Private WireGuard key"
  value       = wireguard_asymmetric_key.wireguard_key.private_key
  sensitive   = true
}

output "wg_instance_id" {
  description = "The ID of the instance"
  value       = aws_instance.wireguard.id
}

output "rendered_user_data" {
  value = templatefile("${path.module}/templates/server.tpl", {
    server_private_key = wireguard_asymmetric_key.wireguard_key.private_key
    server_public_key  = wireguard_asymmetric_key.wireguard_key.public_key
    vpc_cidr           = var.vpc_cidr
    wg_server          = aws_eip.wireguard.public_ip
    vpc_dns_resolver   = local.vpc_dns_resolver
    peer_blocks        = join("\n", local.peer_blocks)
  })
  sensitive = true
}

output "ami_id" {
  value = aws_instance.wireguard.ami
}

output "client_configs" {
  description = "A list of client configuration files, one for each client defined in the `clients` variable."
  value       = local.client_configs
  sensitive   = true
}

output "server_public_ip" {
  description = "Public IP of the WireGuard server."
  value       = aws_eip.wireguard.public_ip
}