
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
    Name = "asg-web-servers-alb"
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



