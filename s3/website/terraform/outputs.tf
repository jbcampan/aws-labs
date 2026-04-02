output "bucket_name" {
  description = "Nom du bucket S3 créé"
  value       = aws_s3_bucket.my_bucket.id
}

output "bucket_arn" {
  description = "ARN du bucket S3 créé"
  value       = aws_s3_bucket.my_bucket.arn
}

output "website_url" {
  value = "http://${aws_s3_bucket.my_bucket.bucket}.s3-website.${var.aws_region}.amazonaws.com"
}