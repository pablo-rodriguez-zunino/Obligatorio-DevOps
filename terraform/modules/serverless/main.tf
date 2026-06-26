# 1. Definición de la Función Lambda
resource "aws_lambda_function" "alerts_processor" {
  function_name = "${var.app_name}-sns-logger-${var.environment}"
  
  # Usamos el LabRole de la cuenta de estudiante (el mismo de tus tareas de ECS)
  role          = "arn:aws:iam::914465196685:role/LabRole"
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  timeout       = 10

  # Código de la función inline para no lidiar con archivos zip externos en el pipeline
  filename      = "${path.module}/dummy_payload.zip"
  # Truco para que Terraform cree un zip básico temporal si no existe
  depends_on    = [null_resource.zip_generation]
}

# Generador del paquete zip básico para Python inline
resource "null_resource" "zip_generation" {
  provisioner "local-exec" {
    command = "echo 'def lambda_handler(event, context): print(\"--- ALERTA RECIBIDA POR SERVERLESS ---\"); print(event); return {\"status\": \"logged\"}' > index.py && zip dummy_payload.zip index.py"
    interpreter = ["sh", "-c"] # Cambiar por ["cmd", "/c"] si usás Windows puro sin Git Bash, pero en Git Bash corre directo
  }
}

# 2. Permiso para que SNS pueda ejecutar tu Lambda
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alerts_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# 3. Integración/Suscripción de la Lambda al Topic de SNS existente
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alerts_processor.arn
}
