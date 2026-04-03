######################################
# IAM Users
######################################

resource "aws_iam_user" "users" {
  for_each = var.users

  name = each.key
}

######################################
# IAM Groups
######################################

resource "aws_iam_group" "groups" {
  for_each = toset(values(var.users))

  name = each.key
}

######################################
# Memberships (bonne pratique)
######################################

resource "aws_iam_user_group_membership" "memberships" {
  for_each = var.users

  user = aws_iam_user.users[each.key].name

  groups = [
    aws_iam_group.groups[each.value].name
  ]
}

######################################
# Policy Attachments
######################################

resource "aws_iam_group_policy_attachment" "group_policies" {
  for_each = {
    developers = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    readonly   = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }

  group      = aws_iam_group.groups[each.key].name
  policy_arn = each.value
}
