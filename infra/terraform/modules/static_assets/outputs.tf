output "bucket_arn" {
  value = aws_s3_bucket.assets.arn
}

output "bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "cdn_domain_name" {
  value = aws_cloudfront_distribution.assets.domain_name
}

output "distribution_id" {
  value = aws_cloudfront_distribution.assets.id
}
