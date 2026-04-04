######################################
# S3 Bucket
######################################

resource "aws_s3_bucket" "my_bucket" {
  bucket = var.mybucket

}

######################################
# Add Object in S3 Bucket
######################################

resource "aws_s3_object" "test_file" {
  bucket  = aws_s3_bucket.my_bucket.id
  key     = "hello.txt"
  content = "Hello depuis le lab-02 !"
}

######################################
# IAM Users
######################################

resource "aws_iam_user" "users" {
  for_each = var.users

  name = each.key
}

######################################
# IAM Policy
######################################

resource "aws_iam_policy" "readonly_s3_policy" {
  name   = "readonly-s3-policy"
  policy = data.aws_iam_policy_document.readonly_s3_policy.json
}

data "aws_iam_policy_document" "readonly_s3_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.my_bucket.arn,
      "${aws_s3_bucket.my_bucket.arn}/*",
    ]
  }
}

######################################
# IAM Role
######################################

resource "aws_iam_role" "role" {
  name = "readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [                               # Les utilisateurs qui pourront assumer le rôle
            aws_iam_user.users["user3"].arn,
            "arn:aws:iam::${var.aws_account_id}:user/aws-labs-user"
            ]  
        }
      },
    ]
  })
}


######################################
# Role Policy Attachments
######################################

resource "aws_iam_role_policy_attachment" "role_policy" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.readonly_s3_policy.arn
}