# =============================================================================
# RED DE AWS (VPC 10.40.0.0/16)
#
# OJO: esto es la red de la NUBE. La red de la OFICINA del equipo es otra:
# 192.168.12.0/24 (DC01 .10, SRV01 .11, ADMIN01 .20...). Van separadas a propósito:
# si los rangos no se solapan, se podrían unir por VPN sin conflictos.
#
#   Subred        AZ a            AZ b            AZ c            Uso
#   pública       10.40.1.0/24    10.40.2.0/24    -               ALB, instancia NAT
#   app           10.40.11.0/24   10.40.12.0/24   -               servidores web, EFS
#   datos         10.40.21.0/24   10.40.22.0/24   10.40.23.0/24   SQL1, SQL2, DC1, RDS
#
# Pública = su tabla de rutas sale a Internet por el Internet Gateway.
# Privada = sale por la instancia NAT (puede salir, pero nadie puede entrar).
# =============================================================================

# Zonas de disponibilidad de la región (us-east-1a, 1b, 1c...)
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  # cidrsubnet("10.40.0.0/16", 8, 1) = "10.40.1.0/24", etc.
  public_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, 1 + i)]  # .1 y .2
  app_cidrs    = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, 11 + i)] # .11 y .12
  data_cidrs   = [for i in range(3) : cidrsubnet(var.vpc_cidr, 8, 21 + i)] # .21, .22 y .23
}

# ---------------- VPC ----------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

# ---------------- Puerta a Internet ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

# ---------------- Subredes ----------------
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-public-${local.azs[count.index]}" }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-app-${local.azs[count.index]}" }
}

resource "aws_subnet" "data" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.data_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-data-${local.azs[count.index]}" }
}

# ---------------- Tablas de rutas ----------------
# Pública: todo lo que no sea de la VPC sale por el Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Privada: todo lo que no sea de la VPC sale por la instancia NAT (nat.tf)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}

# Qué subred usa qué tabla
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  count          = 3
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private.id
}
