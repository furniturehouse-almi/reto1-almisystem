# Datos que Terraform enseña al acabar (y que usarán los siguientes pasos)
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "app_subnets" {
  value = aws_subnet.app[*].id
}

output "data_subnets" {
  value = aws_subnet.data[*].id
}

output "nat_instance" {
  value = {
    id         = aws_instance.nat.id
    private_ip = aws_instance.nat.private_ip
    public_ip  = aws_instance.nat.public_ip
  }
}

output "windows" {
  description = "ID e IP de cada máquina Windows"
  value = {
    for k, i in aws_instance.windows : k => {
      id = i.id
      ip = i.private_ip
    }
  }
}

output "rdp_por_ssm" {
  description = "Túnel RDP sin abrir puertos. Cambia <ID> por el de la máquina y luego: mstsc /v:localhost:13389"
  value       = "aws ssm start-session --target <ID> --document-name AWS-StartPortForwardingSession --parameters portNumber=3389,localPortNumber=13389"
}
