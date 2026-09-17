# the data lake bucket - bronze/silver/gold layout
resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name
}
# these are just empty placeholder objects so the "folders" show up in the console
resource "aws_s3_object" "bronze" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "bronze/"
}
resource "aws_s3_object" "silver" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "silver/"
}
resource "aws_s3_object" "gold" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "gold/"
}

# fires the transform lambda whenever a new file lands in bronze/
# depends_on is required here - otherwise s3 can try to wire this up before
# the lambda has permission to be invoked, and apply fails
resource "aws_s3_bucket_notification" "bronze_trigger" {
  bucket = aws_s3_bucket.data_lake.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.transform.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "bronze/"
  }
  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}