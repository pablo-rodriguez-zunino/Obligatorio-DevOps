variable "app_name" {
  description = "Nombre de la aplicación"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "service_name" {
  description = "Nombre del servicio ECS"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (para métricas CloudWatch)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Sufijo del ARN del Target Group (para métricas CloudWatch)"
  type        = string
}

variable "alarm_email" {
  description = "Email para notificaciones de alarmas (vacío = sin suscripción)"
  type        = string
  default     = ""
}

variable "cpu_threshold" {
  description = "Porcentaje de CPU para disparar alarma"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Porcentaje de memoria para disparar alarma"
  type        = number
  default     = 80
}

variable "error_5xx_threshold" {
  description = "Cantidad de errores 5XX en 5 minutos para disparar alarma"
  type        = number
  default     = 10
}

variable "response_time_threshold" {
  description = "Tiempo de respuesta promedio en segundos para disparar alarma"
  type        = number
  default     = 2
}

variable "unhealthy_hosts_threshold" {
  description = "Cantidad de hosts no saludables para disparar alarma"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "Región AWS donde se despliegan los recursos"
  type        = string
}
