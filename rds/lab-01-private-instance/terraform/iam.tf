#############################################
# EC2 Assume Role
#############################################
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#############################################
# EC2 Role
#############################################
resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

#############################################
# SSM — accès Session Manager
#############################################
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################
# Secrets Manager — lecture du secret RDS
#
# Avec manage_master_user_password = true, AWS crée le secret
# automatiquement. On ne connaît pas son ARN exact à l'avance,
# mais on peut le restreindre par préfixe : RDS nomme toujours
# ses secrets "rds!db-<uuid>". On utilise une wildcard sur le
# compte pour éviter une dépendance circulaire (le secret n'existe
# pas encore quand IAM est créé).
#############################################
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "read_rds_secret" {
  statement {
    sid    = "ReadRDSManagedSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:rds!*"
    ]
  }
}

resource "aws_iam_role_policy" "read_rds_secret" {
  name   = "read-rds-secret"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.read_rds_secret.json
}

#############################################
# Instance Profile
#############################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}