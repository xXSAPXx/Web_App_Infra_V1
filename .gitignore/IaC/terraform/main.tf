
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
# Crate -- VPC / Subnets / Nat_Gateway / RDS_Subnet_Group /Routing / Route53_Private_Zone
#----------------------------------------------------------------------------------------

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





##################################################################
# Create a security group for the RDS instance:
##################################################################

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]  # (Only inside VPC)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/24"] # (Only inside VPC)
  }

  tags = {
    Name = "App_RDS_SG_IaC"
  }
}

################################################################################
# Create an RDS Instance in the Private Subnet Group (2 private_subnets)
################################################################################
resource "aws_db_instance" "mydb" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  storage_encrypted    = true

#db_name              = "calc_app_rds_iac"    # No need since we restore from snapshot.
#username             = "admin"               # No need since we restore from snapshot.
#password             = "12345678"            # No need since we restore from snapshot.

  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.mydb_subnet_group.name

  snapshot_identifier  = "calculator-app-rds-final-snapshot-iac"  # Replace with your snapshot ID from which you want the DB to be created 
  
  # Prevent deletion of the database
  final_snapshot_identifier = "calculator-app-rds-final-snapshot-iac2"
  skip_final_snapshot       = false
}



# Pass the DB_ENDPOINT Variable to the userdata script:
# Pass the ZONE_ID Variable to the userdata script:
locals {
  userdata = templatefile("${path.module}/userdata_for_asg_launch_template.tpl", {
    db_endpoint = aws_db_instance.mydb.endpoint
    private_dns_zone_id = aws_route53_zone.private.id
  })
}



##################################################################
# Security Group allowing HTTP/HTTPS for the Public ALB
##################################################################

resource "aws_security_group" "lb_security_group" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow incoming HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Allow incoming HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (Ensures that the ELB can reach any required service without restrictions!)"
  }

  tags = {
    Name = "lb_security_group"
  }
}


########################################################################################################
# Target Groups Creation for ALB (Frontend / Backend)
########################################################################################################


# Frontend Target Group Creation: (httpd service)
resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  
  health_check {
    path                = "/"  # Path to your health_check.html file OR "/" FOR GENERIC ROOT_PATH HEALTH_CHECK
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

    tags = {
    Name = "FrontendTargetGroup"
  }
}


# Backend Target Group Creation: (Node.js)
resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
  path                = "/health" # Backend Server Endpoint Health Check defined in server.js:
  interval            = 30
  timeout             = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  matcher             = "200"
}
    tags = {
    Name = "BackendTargetGroup"
  }
}



##################################################################################################################
# Application Load Balancer (ALB) / ALB Listeners for HTTP and HTTPS Routing To The ALB Target Group 
##################################################################################################################

# Define the Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "Application-Load-Balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_security_group.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]   # We need 2 Subnets for the ALB to work
  
  
  enable_deletion_protection = false

  tags = {
    Name = "web-alb"
  }
}

# Define ALB HTTP Listener to be Redirected from HTTP:80 to HTTPS:443
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }

  }
}

# Define ALB HTTPS Listener (With the relevant TLS Cert:)
# Forward if path is `/` or `/*.html` or similar → frontend-tg
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Listener Rule To Send /api/* To Backend:
# Forward if path starts with `/api/*` → backend-tg
resource "aws_lb_listener_rule" "backend_api_route" {
  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}




########################################################################################################
# Create Amazon-issued TLS certificate for our domain: [Specifies DNS validation.] AND VALIDATE CERT! 
########################################################################################################

module "alb_cert" {
  source = "./modules/alb_ssl_cert_validation"
  domain_name         = "xxsapxx.uk"
  san                 = ["www.xxsapxx.uk"]
  cloudflare_zone_id  = var.cloudflare_zone_id










##################################################################
# Security Group for the EC2s (Web_Servers)
##################################################################

resource "aws_security_group" "web_servers_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"] # Only inside VPC
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_prometheus_sg.id] # Only the bastion_host can SSH here! 
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"] # Only inside VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_servers_sg"
  }
}


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





########################################################################
# Security Group for the Public EC2 - Bastion + Prometheus server: 
########################################################################

resource "aws_security_group" "bastion_prometheus_sg" {
  name        = "bastion-prometheus-sg"
  description = "Allow SSH and Prometheus and Node_Exporter"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



########################################################################
# Public EC2 - Jump_Host + Prometheus server:
########################################################################

resource "aws_instance" "bastion_prometheus" {
  ami                    = "ami-0583d8c7a9c35822c"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.bastion_prometheus_sg.id] 
  key_name               = "Test.env"
  user_data              = "${file("userdata_for_bastion_prometheus_host.tpl")}"
                          
  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "Bastion-Prometheus-IaC"
  }
}


