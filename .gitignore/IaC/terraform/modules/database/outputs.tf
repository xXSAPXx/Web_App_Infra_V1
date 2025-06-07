
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.mydb.endpoint
}

output "rds_instance_identifier" {
  description = "The identifier of the RDS instance"
  value       = aws_db_instance.mydb.id
}

output "rds_security_group_id" {
  description = "The ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}

output "rds_subnet_group_name" {
  description = "The DB subnet group name used by the RDS instance"
  value       = aws_db_instance.mydb.db_subnet_group_name
}
