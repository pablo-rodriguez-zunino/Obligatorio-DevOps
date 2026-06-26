# 1. Generar el archivo index.py dinámicamente
resource "local_file" "lambda_code" {
  filename = "${path.module}/index.py"
  content  = <<EOT
def lambda_handler(event, context):
    print("--- ALERTA RECIBIDA POR SERVERLESS ---")
    print(event)
    return {"status": "logged"}
EOT
}

# 2. Crear el archivo ZIP de forma nativa con Terraform (Funciona en cualquier Pipeline)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_code.filename
  output_path = "${path.module}/dummy_payload.zip"
}

# 3. Definición de la Función Lambda
resource "aws_lambda_function" "alerts_processor" {
  function_name = "${var.app_name}-sns-logger-${var.environment}"
  role          = "arn:aws:iam::914465196685:role/LabRole"
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  timeout       = 10

  # Apuntamos al ZIP generado nativamente
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 4. Permiso para que SNS pueda ejecutar tu Lambda
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alerts_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

# 5. Integración/Suscripción de la Lambda al Topic de SNS existente
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alerts_processor.arn
}