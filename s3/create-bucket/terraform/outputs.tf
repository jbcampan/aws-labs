output "bucket_name" {
  description = "Nom du bucket S3 créé"
  value       = aws_s3_bucket.my_bucket.id
}

output "bucket_arn" {
  description = "ARN du bucket S3 créé"
  value       = aws_s3_bucket.my_bucket.arn
}