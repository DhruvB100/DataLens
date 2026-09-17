resource "aws_s3_bucket" "frontend" {
  bucket = "${var.bucket_name}-frontend"
}

# bucket stays fully private - nobody reaches it directly
resource "aws_s3_bucket_public_access_block" "frontend_block" {
    bucket = aws_s3_bucket.frontend.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

# lets cloudfront sign its requests to s3 so the bucket can stay private
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
    name = "frontend_oac"
    origin_access_control_origin_type = "s3"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
    origin {
      domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
      origin_id = "frontendS3Origin"
      origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
    }

    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.html"
    default_cache_behavior {
      allowed_methods = ["GET","HEAD"]
      cached_methods = ["GET","HEAD"]
      target_origin_id = "frontendS3Origin"
      viewer_protocol_policy = "redirect-to-https"

      # forwarded_values is the older way to configure caching
      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      min_ttl = 0
      default_ttl = 3600
      max_ttl = 86400
    }

    restrictions {
      geo_restriction {
        restriction_type = "none"
      }
    }

    viewer_certificate {
      cloudfront_default_certificate = true
    }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
    bucket = aws_s3_bucket.frontend.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {"Service":"cloudfront.amazonaws.com"}
            Action = "s3:GetObject"
            Resource = "${aws_s3_bucket.frontend.arn}/*"

            # ties this policy to THIS distribution specifically
            Condition = {
                StringEquals = {
                    "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
                }
            }
        }]
    })
}