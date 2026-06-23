variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)"
}

# 1. Crear la VPC principal
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "retail-${var.environment}-vpc"
  }
}

# 2. Crear una Subred Pública (Para el Balanceador de Carga - ALB)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "retail-${var.environment}-public-1"
  }
}

# AWS exige al menos DOS subredes en distintas AZ para el Balanceador
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "retail-${var.environment}-public-2"
  }
}

# 3. Crear una Subred Privada (Para los 8 Contenedores / Microservicios)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "retail-${var.environment}-private"
  }
}

# 4. Puerta de salida a Internet para las subredes públicas
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "retail-${var.environment}-igw"
  }
}

# 5. Tabla de ruteo pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "retail-${var.environment}-public-rt"
  }
}

# Asociar subredes públicas a la tabla de ruteo
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# --- OUTPUTS (Para que el resto de los módulos puedan leer estos datos) ---
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
