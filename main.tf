# 1. Specifichiamo i provider richiesti
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2. Configuriamo il provider AWS
provider "aws" {
  region = "us-east-1"
}# 3. TABELLA DYNAMODB PER SALVARE GLI EVENTI
resource "aws_dynamodb_table" "visitor_tracker" {
  name         = "visitor-tracker-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}# 4. RUOLO IAM PER LA LAMBDA
resource "aws_iam_role" "lambda_exec_role" {
  name = "visitor_tracker_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Permessi per scrivere su DynamoDB e creare Log
resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}# 5. IMPACCHETTIAMO IL CODICE PYTHON IN UN FILE ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# 6. FUNZIONE LAMBDA
resource "aws_lambda_function" "visitor_tracker" {
  filename         = "lambda_function.zip"
  function_name    = "visitor_tracker_function"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_tracker.name
    }
  }
}# 7. CREIAMO L'API GATEWAY (HTTP API)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "visitor-tracker-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Integra l'API con la Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_tracker.invoke_arn
}

# Rotta di default per ricevere le chiamate
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Stage per pubblicare l'API subito
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Permesso all'API Gateway di invocare la Lambda
resource "aws_lambda_permission" "api_gw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_tracker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}# 8. BUCKET S3 PER OSPITARE IL SITO WEB STATICO
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "frontend" {
  bucket        = "visitor-tracker-frontend-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "frontend_config" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

# Carica il file index.html nel Bucket S3
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}

# 9. OUTPUT FINALI (Per stampare gli URL a fine esecuzione)
output "api_endpoint" {
  value = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.frontend_config.website_endpoint
}