resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-pg"
  family = "postgres14"

  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "main" {
  identifier                 = "${var.project_name}-${var.environment}"
  engine                     = "postgres"
  engine_version             = "14"
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  port                       = var.db_port
  parameter_group_name       = aws_db_parameter_group.main.name
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  skip_final_snapshot        = true
  deletion_protection        = var.enable_deletion_protection
  multi_az                   = false
  publicly_accessible        = true
  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true
}


