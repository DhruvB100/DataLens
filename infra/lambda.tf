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

#========================================================================#

resource "aws_iam_role" "transform_lambda_role" {
  name = "datalens-transform-role"
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

resource "aws_iam_role_policy_attachment" "transform_basic_exec" {
    role = aws_iam_role.transform_lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "transform_s3_access" {
  name = "write_to_s3"
    role = aws_iam_role.transform_lambda_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:PutObject",
                    "s3:GetObject"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}/*"
            }
        ]
    })
}

data "archive_file" "transform_zip" {
    type = "zip"
    source_file = "../lambdas/transform/handler.py"
    output_path = "transform.zip"
}

resource "aws_lambda_function" "transform" {
  function_name = "datalens-transform"
  role = aws_iam_role.transform_lambda_role.arn

  handler = "handler.handler"
  runtime = "python3.12"

  timeout = 60

  filename = data.archive_file.transform_zip.output_path
  source_code_hash = data.archive_file.transform_zip.output_base64sha256

  environment {
    variables = {
        DATA_BUCKET = aws_s3_bucket.data_lake.id
    }
  }
  
  memory_size = 512

  layers = [
    "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:31"
  ]
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id = "AllowS3Invoke"
  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.transform.function_name

  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.data_lake.arn
}