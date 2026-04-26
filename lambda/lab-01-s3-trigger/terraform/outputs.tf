output "source_bucket_name" {
  description = "Nom du bucket source — uploadez vos CSV ici dans le préfixe uploads/"
  value       = aws_s3_bucket.source.bucket
}

output "destination_bucket_name" {
  description = "Nom du bucket destination — les JSON transformés apparaissent ici dans processed/"
  value       = aws_s3_bucket.destination.bucket
}

output "lambda_function_name" {
  description = "Nom de la fonction Lambda"
  value       = aws_lambda_function.processor.function_name
}

output "cloudwatch_log_group" {
  description = "Log Group CloudWatch pour observer les invocations et le cold start"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "upload_command" {
  description = "Commande AWS CLI pour tester le déclenchement (remplace le nom du fichier CSV)"
  value       = "aws s3 cp sample.csv s3://${aws_s3_bucket.source.bucket}/uploads/sample.csv"
}

output "watch_logs_command" {
  description = "Commande pour suivre les logs en temps réel"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow"
}
