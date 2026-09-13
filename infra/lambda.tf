# ===== ingest lambda: fetches the usgs feed, drops raw json in bronze/ =====
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
# ===== transform lambda: bronze json -> cleaned parquet in gold/ =====
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

  # aws-managed layer with pandas + pyarrow preinstalled, too big to zip ourselves
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

#======================================================================
# ===== query lambda: serves /stats, /recent, /largest via athena =====
resource "aws_iam_role" "query_lambda_role" {
  name = "datalens-query-role"
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

resource "aws_iam_role_policy_attachment" "query_basic_exec" {
  role = aws_iam_role.query_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "query_access" {
    name = "query_from_s3"
    role = aws_iam_role.query_lambda_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {  
                Effect = "Allow"
                Action = [
                    "athena:StartQueryExecution",
                    "athena:GetQueryExecution",
                    "athena:GetQueryResults"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "glue:GetTable",
                    "glue:GetPartitions",
                    "glue:GetDatabase"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObject"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}/*"
            },
            {
                # athena needs GetBucketLocation to check the output bucket
                # before it'll write query results there
                Effect = "Allow"
                Action = [
                    "s3:ListBucket",
                    "s3:GetBucketLocation"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}"
            }
        ]
    })
}

data "archive_file" "query_zip" {
    type = "zip"
    source_file = "../lambdas/query/handler.py"
    output_path = "query.zip"
}

resource "aws_lambda_function" "query" {
    function_name = "datalens-query"
    role = aws_iam_role.query_lambda_role.arn
    handler = "handler.handler"
    runtime = "python3.12"

    filename = data.archive_file.query_zip.output_path
    source_code_hash = data.archive_file.query_zip.output_base64sha256

    timeout = 30
    
    environment {
      variables = {
        GLUE_DB = "datalens"
        ATHENA_OUTPUT = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"
      }
    }
}

#============================================================================
# ===== ai_query lambda: natural language question -> sql -> answer =====
# same athena/glue/s3 permissions as the query lambda since this runs its
# own queries too, plus it needs the gemini key to actually talk to the llm
resource "aws_iam_role" "ai_query_lambda_role" {
  name = "datalens-ai-query-role"
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

resource "aws_iam_role_policy_attachment" "ai_query_basic_exec" {
  role = aws_iam_role.ai_query_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ai_query_access" {
  name = "ai_query"
    role = aws_iam_role.ai_query_lambda_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {  
                Effect = "Allow"
                Action = [
                    "athena:StartQueryExecution",
                    "athena:GetQueryExecution",
                    "athena:GetQueryResults"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "glue:GetTable",
                    "glue:GetPartitions",
                    "glue:GetDatabase"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObject"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}/*"
            },
            {
                Effect = "Allow"
                Action = [
                    "s3:ListBucket",
                    "s3:GetBucketLocation"
                ]
                Resource = "${aws_s3_bucket.data_lake.arn}"
            }
        ]
    })
}

data "archive_file" "ai_query_zip" {
  type = "zip"
  source_file = "../lambdas/ai_query/handler.py"
  output_path = "ai_query.zip"
}

resource "aws_lambda_function" "ai_query" {
  function_name = "datalens-ai-query"
  role = aws_iam_role.ai_query_lambda_role.arn

  handler = "handler.handler"
  runtime = "python3.12"

  filename = data.archive_file.ai_query_zip.output_path
  source_code_hash = data.archive_file.ai_query_zip.output_base64sha256

  timeout = 30

  environment {
    variables = {
        GLUE_DB = "datalens"
        ATHENA_OUTPUT = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"
        GEMINI_API_KEY = var.gemini_api_key
    }
  }
  
}