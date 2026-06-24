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

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "retail-${var.environment}-public-2"
  }
}

# 3. Crear una Subred Privada (Para los Contenedores)
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

# ==========================================
# ◄ CORRECCIÓN: Ruteo explícito para la Subred Privada y Endpoints
# ==========================================

# 1. Creamos una tabla de ruteo exclusiva para la subred privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "retail-${var.environment}-private-rt"
  }
}

# 2. Asociamos la subred privada a su tabla de ruteo
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# 3. Grupo de seguridad interno para los Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "retail-${var.environment}-endpoints-sg"
  description = "Permitir trafico HTTPS interno hacia los servicios de AWS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Endpoint para ECR API (Autenticación)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "retail-${var.environment}-ecr-api-vpce" }
}

# Endpoint para ECR DKR (Descarga de imágenes)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "retail-${var.environment}-ecr-dkr-vpce" }
}

# Endpoint de tipo Gateway para S3 (Asociado a AMBAS tablas de ruteo)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = { Name = "retail-${var.environment}-s3-vpce" }
}

# --- OUTPUTS ---
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}