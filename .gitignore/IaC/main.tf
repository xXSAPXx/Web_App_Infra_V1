
################################################################################################################
############ CLOUDFLARE PROVIDER ######################## CLOUDFLARE PROVIDER ##################################

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
    }
  }
}

# Set Variable for CloudFlare API_KEY: 
variable "cloudflare_api_token" {
  type        = string
  description = "API token with DNS edit permissions"
  sensitive   = true
  nullable    = false
}

# Set Variable for CloudFlare ZONE_ID: 
variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID for the Cloudflare domain"
  nullable    = false
}


provider "cloudflare" {
  api_token = var.cloudflare_api_token
}


# Select Domain: 
data "cloudflare_zones" "selected" {
    name = "xxsapxx.uk"
}


# Change DNS Records to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "alb_record" { 
  zone_id = var.cloudflare_zone_id                      # Domain Zone ID
  comment = "Domain pointed to AWS_ALB"                 #
  name    = "www"                                       # Creates www.xxsapxx.uk
  type    = "CNAME"                                     # ALB doesn't have static IP, use CNAME
  content = aws_lb.web_alb.dns_name                     # Attach DNS Record to AWS ALB DNS
  ttl     = 1                                           # DNS Record TTL 
  proxied = true                                        # Enables Cloudflare HTTPS + caching                                        
}



##########################################################################################################
############ AWS PROVIDER ############################ AWS PROVIDER ######################################

provider "aws" {
  region = "us-east-1"  # Replace with your preferred region
}


###################################################################################
# Create a VPC / 2_Public_Subnets for teh NAT and ALB / Internet_Gateway
###################################################################################

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "App_VPC_IaC"
  }
}


# Create a public subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/28"
  availability_zone = "us-east-1a"   	# Replace with your preferred AZ
  map_public_ip_on_launch = true  		# Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_1_IaC"
  }
}


# Create a second public subnet in a different AZ
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.16/28" 			# Make sure the CIDR block doesn't overlap with the first subnet
  availability_zone = "us-east-1b"   			# Replace with another AZ in your preferred region
  map_public_ip_on_launch = true  				# Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_2_IaC"
  }
}


# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Internet_Gateway_IaC"
  }
}



##################################################################
# Create NAT GATEWAY in only 1 public subnet in 1 AZ
##################################################################

# NAT Gateway in public subnet AZ1
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}



##################################################################
# Create 2 private_subnets for the MySQL DB / ASG / SEC GROUP 
##################################################################


# Create a private subnet in the same AZ as the first public subnet
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.32/28"          # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone = "us-east-1a"            # Same AZ as the first public subnet
  map_public_ip_on_launch = false             # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_1_IaC"
  }
}



# Create a private subnet in the same AZ as the second public subnet
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.48/28"          # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone = "us-east-1b"            # Same AZ as the second public subnet
  map_public_ip_on_launch = false             # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_2_IaC"
  }
}



# Create a subnet group for the RDS instance
resource "aws_db_subnet_group" "mydb_subnet_group" {
  name       = "mydb_subnet_group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "App_DB_Subnet_Group_IaC"
  }
}



##############################################################################
# Create Route_Tables for both public and private subnets: 
##############################################################################


############### PUBLIC ROUTING TABLE and SUBNETS: ###############
# All traffic from the 2 public subnets are going to the Internet Gateway: 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Any traffic destined for an address outside the VPC will be directed to the VPC internet gateway
    gateway_id = aws_internet_gateway.igw.id    
  }

  tags = {
    Name = "public_rt_IaC"
  }
}

# Associate the route table with public_subnet_1
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the route table with public_subnet_2
resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}


############### PRIVATE ROUTING TABLE and SUBNETS: ###############
# All traffic from the private subnets are going to the NAT Gateway: 
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

##### PRIVATE SUBNETS: ##### 
# Associate the route table with the 1st PRIVATE subnet:
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate the route table with the 2nd PRIVATE subnet: 
resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}


##############################################################################
# Create Route53 Private Zone for the private subnets: 
##############################################################################

resource "aws_route53_zone" "private" {
  name = "internal.xxsapxx.local"
  vpc {
    vpc_id = aws_vpc.my_vpc.id
  }
  comment = "Private zone for internal DNS resolution"
}

# Pass the ZONE_ID Variable to the userdata script -- (IN RDS CREATION BLOCK)


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

# Output the RDS endpoint
output "rds_endpoint" {
  value = aws_db_instance.mydb.endpoint
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
# Create Amazon-issued TLS certificate for our domain: [Specifies DNS validation.] / VALIDATE CERT 
########################################################################################################

# This means AWS will provide a DNS CNAME record that you must create (manually or via Terraform) 
# in your domain's DNS (e.g., Cloudflare, Route 53) to prove ownership before the cert is issued.
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = "xxsapxx.uk"
  subject_alternative_names = ["www.xxsapxx.uk"] # Added the www subdomain here
  validation_method = "DNS"

  tags = {
    Environment = "prod"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}


# Create DNS validation record in Cloudflare:
resource "cloudflare_dns_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  ttl     = 60
  proxied = false                   # IMPORTANT: Validation records MUST NOT be proxied by Cloudflare
}



# Wait for the certificate to be validated and issued:
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.alb_cert.arn

  validation_record_fqdns = [
    for record in cloudflare_dns_record.cert_validation : record.name
  ]
}



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
    value               = "WEB_SERVER_IaC"
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
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.bastion_prometheus_sg.id] 
  key_name               = "Test.env"
  user_data              = "userdata_for_bastion_prometheus_host.tpl"

  root_block_device {
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name = "bastion-prometheus"
  }
}


