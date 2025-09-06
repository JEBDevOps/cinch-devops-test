locals {
  # Define a list of clients you want to generate configs for.
  # - name: A friendly name for the client.
  # - address: The client's unique IP address on the VPN network.
  # - allowed_ips: The networks this client can route traffic to through the VPN.
  wireguard_clients = [
    {
      name        = "devops-local"
      address     = "10.8.0.2/32"
      allowed_ips = [var.vpc_cidr, "10.8.0.0/24"]
    }
  ]
}

module "wireguard" {
  count  = var.enable_wireguard ? 1 : 0
  source = "./modules/wireguard"

  env           = var.project_name
  vpc           = aws_vpc.main.id
  vpc_cidr      = var.vpc_cidr
  subnet_ids    = [aws_subnet.public_subnet.id]
  instance_type = var.default_instance_type
  clients       = local.wireguard_clients
  ami_id        = ""
}
