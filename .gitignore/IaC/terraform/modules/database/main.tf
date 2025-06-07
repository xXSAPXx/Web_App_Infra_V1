
##################################################################
# Create a security group for the RDS instance:
##################################################################

resource "aws_security_group" "rds_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.private_cidr_block  # (Only inside VPC)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.private_cidr_block # (Only inside VPC)
  }

  tags = {
    Name = var.rds_security_group_name
  }
}

################################################################################
# Create an RDS Instance in the Private Subnet Group (2 private_subnets)
################################################################################
resource "aws_db_instance" "mydb" {
  engine               = var.rds_engine
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  storage_encrypted    = var.rds_storage_encrypted

  #db_name             = "calc_app_rds_iac"    # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  port                 = var.rds_port
  parameter_group_name = var.rds_parameter_group_name
  publicly_accessible  = var.rds_publicly_accessible
  
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name

  snapshot_identifier  = var.rds_snapshot_identifier  # Replace with your snapshot ID from which you want the DB to be created 
  maintenance_window   = var.maintenance_window

  # Prevent deletion of the database
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.rds_final_snapshot_identifier
}


# Pass the DB_ENDPOINT Variable to the userdata script:
# Pass the ZONE_ID Variable to the userdata script:
locals {
  userdata = templatefile("${path.root}/userdata_for_asg_launch_template.tpl", {
    db_endpoint         = aws_db_instance.mydb.endpoint
    private_dns_zone_id = var.private_dns_zone_id
  })
}

