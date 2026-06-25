variable "services" {
  type    = list(string)
  default = ["ui", "admin", "catalog", "carts", "orders", "checkout", "db"]
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.services)
  name                 = "retail-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
