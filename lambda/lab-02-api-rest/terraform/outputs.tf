output "api_url" {
  description = "URL de base de l'API — utilise cette valeur dans tes commandes curl"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "dynamodb_table_name" {
  description = "Nom de la table DynamoDB créée"
  value       = aws_dynamodb_table.items.name
}

output "dynamodb_table_arn" {
  description = "ARN de la table DynamoDB (utile pour vérifier les policies IAM)"
  value       = aws_dynamodb_table.items.arn
}

# Affiche les commandes curl directement après terraform apply
output "curl_examples" {
  description = "Commandes curl prêtes à l'emploi pour tester l'API"
  value       = <<-EOT
    # ── CREATE ────────────────────────────────────────────────────────────────
    curl -X POST ${aws_apigatewayv2_stage.default.invoke_url}items \
      -H "Content-Type: application/json" \
      -d '{"name": "Laptop", "price": 999, "stock": 10}'

    # ── READ ──────────────────────────────────────────────────────────────────
    curl ${aws_apigatewayv2_stage.default.invoke_url}items/<id-retourné-par-create>

    # ── UPDATE ────────────────────────────────────────────────────────────────
    curl -X PUT ${aws_apigatewayv2_stage.default.invoke_url}items/<id> \
      -H "Content-Type: application/json" \
      -d '{"price": 799, "stock": 5}'

    # ── DELETE ────────────────────────────────────────────────────────────────
    curl -X DELETE ${aws_apigatewayv2_stage.default.invoke_url}items/<id>
  EOT
}
