# Affiche les users créés
output "user_names" {
  value = [for u in aws_iam_user.users : u.name]
}

# Affiche l'ARN du rôle IAM créé
output "role_arn" {
  description = "L'ARN du rôle IAM créé"
  value       = aws_iam_role.role.arn
}

# Affiche le nom du rôle IAM
output "role_name" {
  description = "Le nom du rôle IAM créé"
  value       = aws_iam_role.role.name
}

# Affiche le nom du bucket S3 créé
output "bucket_name" {
  description = "Le nom du bucket S3 créé"
  value       = aws_s3_bucket.my_bucket.bucket
}