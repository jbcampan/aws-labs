variable "aws_region" {
  description = "Région AWS où déployer les ressources"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Préfixe utilisé pour nommer toutes les ressources (doit être unique dans ton compte)"
  type        = string
  default     = "lab01"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name doit contenir uniquement des minuscules, chiffres et tirets (3-20 caractères)."
  }
}
