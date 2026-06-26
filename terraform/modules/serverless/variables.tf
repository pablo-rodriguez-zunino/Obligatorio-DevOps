variable "app_name" {
  type        = string
  description = "Nombre base de la aplicación"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN del Topic de SNS de CloudWatch para integrarse"
}
