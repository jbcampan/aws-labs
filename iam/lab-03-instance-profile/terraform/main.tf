######################################
# S3 Bucket
######################################

resource "aws_s3_bucket" "my_bucket" {
  bucket        = var.mybucket
  force_destroy = true # Permet à Terraform de vider et supprimer le bucket même s'il contient des objets
}

######################################
# Add Object in S3 Bucket
######################################

resource "aws_s3_object" "test_file" {
  bucket  = aws_s3_bucket.my_bucket.id
  key     = "hello.txt"
  content = "Hello depuis le lab-03 !"
  # Fichier de test pré-existant pour valider la lecture depuis l'instance
}

######################################
# IAM Policy
######################################

# La policy définit CE QUE l'on peut faire (les permissions)
# Elle est ensuite attachée à un rôle, pas directement à l'instance
resource "aws_iam_policy" "read_and_write_s3_policy" {
  name   = "read_and_write-s3-policy"
  policy = data.aws_iam_policy_document.read_and_write_s3_policy.json
}

data "aws_iam_policy_document" "read_and_write_s3_policy" {
  statement {
    actions = [
      "s3:GetObject",  # Lire un objet
      "s3:ListBucket", # Lister le contenu du bucket
      "s3:PutObject",  # Écrire un objet
      "s3:DeleteObject"# Supprimer un objet
    ]
    resources = [
      aws_s3_bucket.my_bucket.arn,       # Le bucket lui-même (nécessaire pour ListBucket)
      "${aws_s3_bucket.my_bucket.arn}/*", # Les objets dans le bucket (nécessaire pour Get/Put/Delete)
    ]
  }
}

######################################
# IAM Role
######################################

# Le rôle définit QUI peut utiliser ces permissions
# La trust policy (assume_role_policy) déclare quelle entité AWS peut assumer ce rôle
# Ici : le service EC2 — c'est ce qui permet à une instance d'obtenir des credentials temporaires
resource "aws_iam_role" "role" {
  name = "read_and_write-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # Seul le service EC2 peut assumer ce rôle
        }
      }
    ]
  })
}

######################################
# Role Policy Attachments
######################################

# Attache la policy S3 custom au rôle
resource "aws_iam_role_policy_attachment" "role_policy" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.read_and_write_s3_policy.arn
}

# Attache la policy AWS managée SSM au rôle
# Permet la connexion à l'instance via Session Manager sans clé SSH ni port 22 ouvert
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

######################################
# IAM Instance Profile
######################################

# L'instance profile est le conteneur qu'EC2 attend pour associer un rôle IAM à une instance
# Distinction importante : le rôle IAM existe indépendamment, l'instance profile est le "wrapper" EC2
# On ne peut pas attacher un rôle directement à une instance — il faut passer par l'instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "lab03-ec2-instance-profile"
  role = aws_iam_role.role.name
}

######################################
# EC2 Ubuntu AMI (dernière version Jammy 22.04)
######################################

# Récupère dynamiquement l'AMI Ubuntu la plus récente
# Évite de hardcoder un AMI ID qui devient obsolète avec les mises à jour
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical — filtre pour éviter des AMIs tiers non officielles
}

######################################
# EC2 Instance
######################################

resource "aws_instance" "my_ec2" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  # Pas de clé SSH, pas de security group — l'accès se fait uniquement via Session Manager
  # Les credentials AWS sont résolus automatiquement via le metadata service (169.254.169.254)
  # boto3 et la CLI AWS interrogent cette adresse pour obtenir des credentials temporaires

  tags = {
    Name = "lab03-instance-profile"
  }
}