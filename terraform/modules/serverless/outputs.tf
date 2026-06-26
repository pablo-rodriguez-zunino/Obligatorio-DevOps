output "lambda_function_arn" {
  value       = aws_lambda_function.alerts_processor.arn
  description = "ARN de la función Lambda de monitoreo"
}
