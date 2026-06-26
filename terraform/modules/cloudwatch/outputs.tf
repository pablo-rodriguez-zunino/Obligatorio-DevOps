output "sns_topic_arn" {
  description = "ARN del topic SNS para notificaciones de alarmas"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
