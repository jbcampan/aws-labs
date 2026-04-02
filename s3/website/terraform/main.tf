##############################################
# 1️⃣ Création du bucket S3
##############################################
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
}


##############################################
# 2️⃣ Configuration du bloc d'accès public
##############################################
resource "aws_s3_bucket_public_access_block" "my_public_access" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

    # Permet de rendre le bucket public, nécessaire avant d'appliquer une policy publique
}


##############################################
# 3️⃣ Policy publique pour permettre la lecture des objets
##############################################
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.my_bucket.id

  depends_on = [aws_s3_bucket_public_access_block.my_public_access]
    # Terraform attend que le bloc d'accès public soit désactivé avant d'appliquer la policy

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}


##############################################
# 4️⃣ Upload du fichier index.html dans le bucket
##############################################
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "index.html"
  source = var.path_file

  content_type = "text/html"
    # Permet au navigateur d'afficher la page HTML au lieu de proposer le téléchargement.

  etag = filemd5(var.path_file)
    # Terraform utilise le hash MD5 pour détecter les changements, si le fichier change, Terraform le re-upload automatiquement
}


##############################################
# 5️⃣ Activation du site web statique
##############################################
resource "aws_s3_bucket_website_configuration" "my_website_bucket" {
  bucket = aws_s3_bucket.my_bucket.id

  index_document {
    suffix = "index.html"
  }
}