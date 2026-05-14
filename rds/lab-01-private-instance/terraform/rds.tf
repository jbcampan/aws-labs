resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids
}

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  storage_encrypted       = true
  skip_final_snapshot     = true
  deletion_protection     = false
}