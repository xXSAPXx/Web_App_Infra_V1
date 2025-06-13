


#################################################################################################################################
######################################## CLOUDFLARE PROVIDER VARIABLES ##########################################################

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}



# Create a Cloudflare DNS record to the ALB CNAME or IP - [SSL cert validation is handled in module alb_cert_validation]
module "cloudflare_dns" {
  source = "./modules/cloudflare"

# --- Cloudflare_DNS_Record Settings ---
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  select_domain_name   = "xxsapxx.uk"
  comment              = "Domain pointed to AWS_ALB"
  sub_domain_name      = "www"
  dns_record_type      = "CNAME" 
  dns_ttl              = 1
  proxied              = true 
  alb_dns_name         = module.alb.alb_dns_name
}





####################################################################################################################################
######################################## AWS PROVIDER VARIABLES ####################################################################

# AWS provider region: 
provider "aws" {
  region = "us-east-1"  # Or use a variable if you prefer
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

module "security_groups" {
  source = "./modules/security_groups"

# For all SGs:
vpc_id = module.vpc.vpc_id

# -------- RDS Sec_Group Settings --------
  rds_cidr_block          = "10.0.0.0/24"
  rds_security_group_name = "RDS_SG_IaC"

# --- Bastion_Prometheus_Host Sec_Group Settings ---
  bastion_host_cidr_block = "0.0.0.0/0"
  sec_group_name          = "bastion_prometheus_sg"
  sec_group_description   = "Allow SSH and Prometheus and Node_Exporter Ports"

# --- ALB Sec_Group Settings ---
  alb_sec_group_cidr_block = "0.0.0.0/0"                                                # Public ALB Allows HTTP / HTTPS 
  alb_security_group_name  = "alb_security_group"

# --- Web_Servers Sec_Group Settings ---     
  asg_sec_group_cidr_block = "10.0.0.0/24"
  bastion_host_sec_group   = [module.security_groups.bastion_host_security_group_id] # Only the BASTION_Sec_Group can SSH the WEB_SERVERS! 
  asg_security_group_name  = "asg_servers_sg"
}




# Create All IAM Policies / Roles and IAM Instance Profiles: 
######################################################################################

module "iam" {
  source = "./modules/iam"

# --- IAM Policy Route53 Zone ID ---
  private_dns_zone_id  = module.vpc.private_dns_zone_id

}




# RDS Configuration and Creation:
######################################################################################

module "database" {
  source = "./modules/database"

# -------- RDS Configuration Settings --------

  rds_engine               = "mysql"
  rds_engine_version       = "8.0.35"
  rds_instance_class       = "db.t3.micro"
  rds_allocated_storage    = 20
  rds_storage_encrypted    = true

  #db_name             = "calc_app_rds_iac"    # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  rds_port                 = "3306"
  rds_parameter_group_name = "default.mysql8.0"
  rds_publicly_accessible  = false
  
  rds_security_group_ids = [module.security_groups.rds_security_group_id]
  rds_subnet_group_name  = module.vpc.rds_subnet_group_name

  rds_snapshot_identifier  = "calculator-app-rds-final-snapshot-iac"  # Replace with your snapshot ID from which you want the DB to be created 
  maintenance_window   = "mon:19:00-mon:19:30"
  
  # Prevent deletion of the database
  skip_final_snapshot           = false
  rds_final_snapshot_identifier = "calculator-app-rds-final-snapshot-iac2"
}




# Create and EC2: (Bastion / Prometheus Host)
######################################################################################
module "bastion_prometheus" {
  source = "./modules/bastion_prometheus_host"


  # --- Bastion_Prometheus_Host Settings ---
  ami_id                  = "ami-0583d8c7a9c35822c"
  instance_type           = "t2.micro"
  subnet_id               = module.vpc.public_subnet_2_id
  bastion_sec_group_ids   = [module.security_groups.bastion_host_security_group_id]
  key_name                = "Test.env"
  user_data_path          = filebase64("${path.module}/modules/bastion_prometheus_host/userdata_for_bastion_prometheus_host.tpl")
  iam_instance_profile    = module.iam.prometheus_server_instance_profile_name
                              
  volume_size = 10
  volume_type = "gp2"
  
  bastion_host_tag_name   = "Bastion-Prometheus-IaC"
}




# Create Frontend/Backend - Target Groups / ALB / ALB_Listeners / ALB Rules 
######################################################################################
module "alb" {
  source = "./modules/alb"


# --- Target Groups Settings (Frontend / Backend) ---
  vpc_id = module.vpc.vpc_id

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
  backend_tg_path                 = "/backend"
  backend_tg_interval             = 30
  backend_tg_timeout              = 5
  backend_tg_healthy_threshold    = 2
  backend_tg_unhealthy_threshold  = 2
  backend_tg_matcher              = "200"

  backend_tg_tag_name  = "BackendTargetGroup"


# ----------- ALB Configuration Settings -----------
  alb_name                       = "alb-web-servers-asg"
  alb_subnets                    = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]   # We need 2 Subnets for the ALB to work
  alb_security_groups            = [module.security_groups.alb_security_group_id]
  alb_load_balancer_type         = "application"
  alb_internal                   = false
  alb_enable_deletion_protection = false

  alb_tag_name                   = "asg-web-servers-alb"


# ----------- ALB Listeners Configuration Settings -----------
  
  # HTTP Listener: 
  # Forwards All Taffic on port 80 to HTTPS(443) --> aws_lb_target_group.frontend_tg.arn
  http_listener_port                  = 80  
  # Redirect to HTTPS: 
  http_listener_redirect_protocol     = "HTTPS"
  http_listener_redirect_port         = "443"
  http_listener_redirect_status_code  = "HTTP_301"
  

  # HTTPS Listener: 
  # Forwards All Taffic on port 443 to --> aws_lb_target_group.frontend_tg.arn
  https_listener_port                 = 443
  https_listener_ssl_policy           = "ELBSecurityPolicy-2016-08"
  https_listener_certificate_arn      = module.alb_ssl_cert_validation.alb_certificate_arn

  # ALB Rules for HTTPS Listener: 
  # List of path patterns to forward to the backend_tg
  backend_path_patterns = ["/api/*"]
}



# Create Amazon-issued TLS certificate for our domain: [Specifies DNS validation.] AND VALIDATE CERT! 
########################################################################################################

module "alb_ssl_cert_validation" {
  source = "./modules/alb_ssl_cert_validation"
  domain_name         = "xxsapxx.uk"
  san                 = ["www.xxsapxx.uk"]
  cloudflare_zone_id  = var.cloudflare_zone_id
  validation_method   = "DNS"
}



# Create Lunch Template and the ASG:  
########################################################################################################
module "asg" {
  source = "./modules/asg"
  depends_on = [module.database] # Ensure the launch configuration is created only after the RDS Module.


# --- Pass DB_ENDPOINT and PRIVATE_DNS_ZONE to Lunch Template User_Data_Script: ---
  database_endpoint   = module.database.rds_endpoint
  private_dns_zone_id = module.vpc.private_dns_zone_id



# --- Launch Template Settings ---
  launch_template_name_prefix             = "web-server-template"
  launch_template_image_id                = "ami-0583d8c7a9c35822c"
  launch_template_instance_type           = "t2.micro"
  launch_template_key_name                = "Test.env"
  launch_template_instance_profile        = module.iam.launch_template_instance_profile_name

# EBS: 
  launch_template_device_name             = "/dev/xvda"
  launch_template_volume_size             = 10
  launch_template_volume_type             = "gp2"

  launch_template_security_groups = [module.security_groups.asg_security_group_id]



# --- ASG Configuration Settings ---
  asg_min_size                    = 1
  asg_max_size                    = 3
  asg_desired_capacity            = 1
  asg_vpc_zone_identifier         = [module.vpc.private_subnet_1_id, module.vpc.private_subnet_2_id]
  asg_target_group_arns           = [module.alb.frontend_target_group_arn, module.alb.backend_target_group_arn]
  asg_health_check_type           = "ELB" 
  asg_health_check_grace_period   = 300
  asg_tag_name                    = "Web-Server-IaC"
  asg_propagate_name_at_launch    = true
}


# Create Scaling Policies for the ASG based on Cloud_Watch Metrics:  
########################################################################################################

module "cloud_watch_alarm_and_scale_policies" {
  source = "./modules/asg_scaling_policies"

# --- CPU above 70% Cloud_Watch Alarm Settings ---
  cpu_above_70_alarm_alarm_name             = "cpu_alarm_high"
  cpu_above_70_alarm_comparison_operator    = "GreaterThanThreshold"
  cpu_above_70_alarm_evaluation_periods     = "2"
  cpu_above_70_alarm_metric_name            = "CPUUtilization"
  cpu_above_70_alarm_namespace              = "AWS/EC2"
  cpu_above_70_alarm_period                 = "120"
  cpu_above_70_alarm_statistic              = "Average"
  cpu_above_70_alarm_threshold              = "70"
  cpu_above_70_alarm_alarm_description      = "This metric monitors the average CPU utilization and triggers if it goes above 70%."
  cpu_above_70_alarm_actions_enabled        = true
  cpu_above_70_alarm_autoscaling_group_name = module.asg.autoscaling_group_name

# --- Scale out policy triggered by CPU above 70% Cloud_Watch Alarm ---
  scale_out_policy_name                     = "scale_out_policy"
  scale_out_policy_scaling_adjustment       = 1
  scale_out_policy_adjustment_type          = "ChangeInCapacity"
  scale_out_policy_cooldown                 = 120
  scale_out_policy_autoscaling_group_name   = module.asg.autoscaling_group_id



# --- CPU below 50% Cloud_Watch Alarm Settings ---
  cpu_below_50_alarm_alarm_name             = "cpu_alarm_low"
  cpu_below_50_alarm_comparison_operator    = "LessThanThreshold"
  cpu_below_50_alarm_evaluation_periods     = "2"
  cpu_below_50_alarm_metric_name            = "CPUUtilization"
  cpu_below_50_alarm_namespace              = "AWS/EC2"
  cpu_below_50_alarm_period                 = "120"
  cpu_below_50_alarm_statistic              = "Average"
  cpu_below_50_alarm_threshold              = "50"
  cpu_below_50_alarm_alarm_description      = "This metric monitors the average CPU utilization and triggers if it goes below 50%."
  cpu_below_50_alarm_actions_enabled        = true
  cpu_below_50_alarm_autoscaling_group_name = module.asg.autoscaling_group_name

# --- Scale out policy triggered by CPU below 50% Cloud_Watch Alarm ---
  scale_in_policy_name                      = "scale_in_policy"
  scale_in_policy_scaling_adjustment        = -1
  scale_in_policy_adjustment_type           = "ChangeInCapacity"
  scale_in_policy_cooldown                  = 120
  scale_in_policy_autoscaling_group_name    = module.asg.autoscaling_group_id
}



# Print all dynamic variables passed to specified modules after terrafrom deployment: 
# Usefull for debuging purposes.
# This ensures the modules received the correct env variables. 
########################################################################################################

output "private_dns_zone_id" {
  value = module.asg.private_dns_zone_debug
}

output "rds_endpoint_id" {
  value = module.asg.rds_endpoint_debug
}

