
################################################################################################################
############ CLOUDFLARE PROVIDER ######################## CLOUDFLARE PROVIDER ##################################

# Cloudflare Provider: 
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
    }
  }
}


# Create a Cloudflare DNS record to the ALB CNAME or IP - [SSL cert validation is handled in module alb_cert_validation]
module "cloudflare_dns" {
  source               = "./modules/cloudflare"
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  select_domain_name   = "xxsapxx.uk"
  comment              = "Domain pointed to AWS_ALB"
  sub_domain_name      = "www"
  dns_record_type      = "CNAME" 
  dns_ttl              = 1
  proxied              = true 
  alb_dns_name         = aws_lb.web_alb.dns_name
}


###################################################################################################################
############ AWS PROVIDER ################################## AWS PROVIDER #########################################

# AWS Provider: 
provider "aws" {
  region = "us-east-1"  # Replace with your preferred region
}


# Networking: 
# Crate VPC / Subnets / Nat_Gateway / RDS_Subnet_Group /Routing / Route53_Private_Zone
######################################################################################

module "vpc" {
  source = "./modules/vpc"

  # --- General VPC Settings ---
  vpc_name       = "App_VPC_IaC"
  vpc_cidr_block = "10.0.0.0/24"
  internet_gateway_name = "Internet_Gateway_IaC"

  # --- Availability Zone Settings ---
  availability_zone_1 = "us-east-1a"
  availability_zone_2 = "us-east-1b"

  # --- Subnet CIDR Block Settings ---
  public_subnet_1_cidr  = "10.0.0.0/28"
  public_subnet_2_cidr  = "10.0.0.16/28"
  private_subnet_1_cidr = "10.0.0.32/28"
  private_subnet_2_cidr = "10.0.0.48/28"
  
  # --- NAT_Gateway Settings ---
  nat_gateway_public_subnet_id = 1

  # --- RDS Subnet Group Settings ---
  rds_subnet_group_name = "App_DB_Subnet_Group_IaC"

  # --- Route 53 Settings ---
  private_zone_name = "internal.xxsapxx.local"
}



# Create ALL Security Groups: 
######################################################################################

module "aws_security" {
  source = "./modules/sec_groups_and_iam"

# For all SGs:
vpc_id = aws_vpc.my_vpc.id

# -------- RDS Sec_Group Settings --------
  rds_cidr_block          = "10.0.0.0/24"
  rds_security_group_name = "RDS_SG_IaC"

# --- Bastion_Prometheus_Host Sec_Group Settings ---
  bastion_host_cidr_block = "0.0.0.0/0"
  sec_group_name          = "bastion_prometheus_sg"
  sec_group_description   = "Allow SSH and Prometheus and Node_Exporter Ports"

# --- ALB Sec_Group Settings ---
  alb_sec_group_cidr_block = "0.0.0.0/0"          # Public ALB Allows HTTP / HTTPS 
  alb_security_group_name  = "alb_security_group"

# --- Web_Servers Sec_Group Settings ---     
  asg_sec_group_cidr_block = "10.0.0.0/24"
  bastion_host_sec_group   = [aws_security_group.bastion_prometheus_sg.id] # Only the BASTION_Sec_Group can SSH the WEB_SERVERS! 
  asg_security_group_name  = "asg_servers_sg"
}




# RDS Configuration and Creation:
######################################################################################

module "database" {
  source = "./modules/database"

# -------- RDS Configuration Settings --------

  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_encrypted    = true

  #db_name             = "calc_app_rds_iac"    # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  port                 = "3306"
  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = false
  
  rds_security_group_ids = [aws_security_group.rds_sg.id]
  rds_subnet_group_name  = aws_db_subnet_group.mydb_subnet_group.name

  snapshot_identifier  = "calculator-app-rds-final-snapshot-iac"  # Replace with your snapshot ID from which you want the DB to be created 
  maintenance_window   = "mon:19:00-mon:19:30"
  
  # Prevent deletion of the database
  skip_final_snapshot       = false
  final_snapshot_identifier = "calculator-app-rds-final-snapshot-iac2"
}




# Create and EC2: (Bastion Prometheus Host)
######################################################################################
module "bastion_prometheus" {
  source          = "./modules/bastion_prometheus_host"


  # --- Bastion_Prometheus_Host Settings ---
  ami_id                  = "ami-0583d8c7a9c35822c"
  instance_type           = "t2.micro"
  subnet_id               = aws_subnet.public_subnet_2.id
  bastion_sec_group_ids   = [aws_security_group.bastion_prometheus_sg.id]
  key_name                = "Test.env"
  user_data_path          = "${path.module}/userdata_for_bastion_prometheus_host.tpl"
  
  volume_size = 10
  volume_type = "gp2"
  
  tags = {
    Name = "Bastion-Prometheus-IaC"
  }
}




# Create Frontend/Backend - Target Groups / ALB / ALB_Listeners / 
######################################################################################
module "alb" {
  source = "./modules/alb"


# --- Target Groups Settings (Frontend / Backend) ---
  vpc_id = aws_vpc.my_vpc.id

# ----------- Frontend TG -----------
  frontend_tg_name     = "frontend-tg"
  frontend_tg_port     = 80
  frontend_tg_protocol = "HTTP"
    
  # Health_Check:
  frontend_tg_path                = "/"   # Path to your health_check.html file OR "/" FOR GENERIC ROOT_PATH HEALTH_CHECK
  frontend_tg_interval            = 30
  frontend_tg_timeout             = 5
  frontend_tg_healthy_threshold   = 2
  frontend_tg_unhealthy_threshold = 2
  frontend_tg_matcher             = "200"

  frontend_tg_tag_name = "FrontendTargetGroup"


# ----------- Backend TG ----------- 
  backend_tg_name      = "backend-tg"
  backend_tg_port      = 3000
  backend_tg_protocol  = "HTTP"
    
  # Health_Check:
  backend_tg_path                 = "/health"
  backend_tg_interval             = 30
  backend_tg_timeout              = 5
  backend_tg_healthy_threshold    = 2
  backend_tg_unhealthy_threshold  = 2
  backend_tg_matcher              = "200"

  backend_tg_tag_name  = "BackendTargetGroup"



# --- ALB Configuration Settings ---
  alb_name                       = "my-alb"
  alb_vpc_id                     = "vpc-abcde012"
  alb_subnets                    = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]   # We need 2 Subnets for the ALB to work
  alb_security_groups            = [aws_security_group.lb_security_group.id]
  alb_load_balancer_type         = "application"
  alb_internal                   = false
  alb_enable_deletion_protection = false

  alb_tag_name                   = "asg-web-servers-alb"









# Create Amazon-issued TLS certificate for our domain: [Specifies DNS validation.] AND VALIDATE CERT! 
########################################################################################################

module "alb_cert" {
  source = "./modules/alb_ssl_cert_validation"
  domain_name         = "xxsapxx.uk"
  san                 = ["www.xxsapxx.uk"]
  cloudflare_zone_id  = var.cloudflare_zone_id
  validation_method   = "DNS"











##################################################################
# Launch Template For Every EC2 Instance: 
##################################################################

resource "aws_launch_template" "web_server_template" {
  name_prefix   = "web-server-template"
  image_id      = "ami-0583d8c7a9c35822c"
  instance_type = "t2.micro"
  key_name      = "Test.env"

  user_data = base64encode(local.userdata)

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 10
      volume_type = "gp2"
    }
  }

  network_interfaces {
    security_groups = [aws_security_group.web_servers_sg.id]
  }

  # Ensure the launch configuration is created only after the RDS instance
  depends_on = [aws_db_instance.mydb]
}


##################################################################
# AUTO SCALING GROUP CREATION
##################################################################

resource "aws_autoscaling_group" "web_server_asg" {
  launch_template {
    id      = aws_launch_template.web_server_template.id
    version = "$Latest"
  }

  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]  # Deploy EC2s in both private subnets

  # This ALB acts like a FRONTEND and BACKEND at the same time so we add both ALB target groups here: 
  target_group_arns = [
  aws_lb_target_group.frontend_tg.arn,
  aws_lb_target_group.backend_tg.arn
  ]

  tag {
    key                 = "Name"
    value               = "Web-Server-IaC"
    propagate_at_launch = true
  }

  health_check_type    = "ELB"  # ALB/ELB compatibility

  # Optionally add health check grace period to allow user data script to run
  health_check_grace_period = 300  # 5 minutes grace period for the instances to finish boot

  depends_on = [aws_launch_template.web_server_template]  # Ensure template is created before ASG
}



##################################################################
# CLOUDWATCH ALARM AND SCALING OUT POLICY (CPU above 70% ALARM)
##################################################################

# Define a CloudWatch Alarm for CPU Utilization Above 70%
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "cpu_alarm_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors the average CPU utilization and triggers if it goes above 70%."
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}

# Define the Scaling Policy for Scaling Out
resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "scale_out_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.id
}


##################################################################
# CLOUDWATCH ALARM AND SCALING IN POLICY (CPU below 50% ALARM)
##################################################################

# Define a CloudWatch Alarm for CPU Utilization Below 50%
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "cpu_alarm_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors the average CPU utilization and triggers if it goes below 50%."
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.scale_in_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}



# Define the Scaling Policy for Scaling In
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "scale_in_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.id
}




