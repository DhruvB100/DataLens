resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name
}
resource "aws_s3_object" "bronze" {
  bucket = aws_s3_bucket.data_lake.id
  key = "bronze/"
}
resource "aws_s3_object" "silver" {
  bucket = aws_s3_bucket.data_lake.id
  key = "silver/"
}
resource "aws_s3_object" "gold" {
  bucket = aws_s3_bucket.data_lake.id
  key = "gold/"
}