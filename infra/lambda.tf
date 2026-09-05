resource "aws_iam_role" "ingest_lambda_role" {
    name = "datalens-ingest-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    }) 
}

resource "aws_iam_role_policy_attachment" "ingest_basic_exec" {
    role = aws_iam_role.ingest_lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ingest_s3_write" {
    name = "write_to_s3"
    role = aws_iam_role.ingest_lambda_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:PutObject"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}/*"
            }
        ]
    })
}

data "archive_file" "ingest_zip" {
    type = "zip"
    source_file = "../lambdas/ingest/handler.py"
    output_path = "ingest.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name = "datalens-ingest"
  role = aws_iam_role.ingest_lambda_role.arn
  
  handler = "handler.handler"
  runtime = "python3.12"

  filename = data.archive_file.ingest_zip.output_path
  source_code_hash = data.archive_file.ingest_zip.output_base64sha256

  timeout = 30

  environment {
    variables = {
        DATA_BUCKET = aws_s3_bucket.data_lake.id
    }
  }
}