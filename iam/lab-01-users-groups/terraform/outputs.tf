output "user_names" {
  value = [for u in aws_iam_user.users : u.name]
}

output "groups" {
  value = [for g in aws_iam_group.groups : g.name]
}