terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "bucket-obligatorio-pablozepp"
    key    = "retailstore/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source      = "./modules/networking"
  environment = var.environment
}

module "ecr" {
  source = "./modules/ecr"
}

# Conectamos el módulo de aplicaciones con la red y el ECR
module "apps" {
  source            = "./modules/apps"
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnets    = module.networking.public_subnets
  private_subnet_id = module.networking.private_subnet_id
  repository_urls   = module.ecr.repository_urls
}

output "url_de_la_tienda" {
  value       = "http://${module.apps.alb_dns_name}"
  description = "Ingresa a esta URL para ver el RetailStore corriendo"
}