variable "environment" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "public_subnets" {
  type        = list(string)
}

variable "private_subnet_id" {
  type        = string
}

variable "repository_urls" {
  type        = map(string)
}

variable "services" {
  type    = list(string)
  default = ["ui", "admin", "catalog", "carts", "orders", "checkout"]
}
