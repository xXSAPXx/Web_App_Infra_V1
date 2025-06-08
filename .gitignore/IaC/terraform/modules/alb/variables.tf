###################################### VPC #######################################
variable "vpc_id" {
  description = "ID of the VPC where the target groups will be created"
  type        = string
}

# ############################ Frontend Target Group #############################
variable "frontend_tg_name" {
  description = "Name of the frontend target group"
  type        = string
  default     = "frontend-tg"
}

variable "frontend_tg_port" {
  description = "Port for the frontend target group"
  type        = number
  default     = 80
}

variable "frontend_tg_protocol" {
  description = "Protocol for the frontend target group"
  type        = string
  default     = "HTTP"
}

variable "frontend_tg_path" {
  description = "Health check path for the frontend target group"
  type        = string
  default     = "/"
}

variable "frontend_tg_interval" {
  description = "Health check interval for the frontend target group"
  type        = number
  default     = 30
}

variable "frontend_tg_timeout" {
  description = "Health check timeout for the frontend target group"
  type        = number
  default     = 5
}

variable "frontend_tg_healthy_threshold" {
  description = "Number of successful health checks for the frontend target group"
  type        = number
  default     = 2
}

variable "frontend_tg_unhealthy_threshold" {
  description = "Number of failed health checks for the frontend target group"
  type        = number
  default     = 2
}

variable "frontend_tg_matcher" {
  description = "HTTP code matcher for the frontend target group"
  type        = string
  default     = "200"
}

variable "frontend_tg_tag_name" {
  description = "Tag name for the frontend target group"
  type        = string
  default     = "FrontendTargetGroup"
}

########################## Backend Target Group #############################
variable "backend_tg_name" {
  description = "Name of the backend target group"
  type        = string
  default     = "backend-tg"
}

variable "backend_tg_port" {
  description = "Port for the backend target group"
  type        = number
  default     = 3000
}

variable "backend_tg_protocol" {
  description = "Protocol for the backend target group"
  type        = string
  default     = "HTTP"
}

variable "backend_tg_path" {
  description = "Health check path for the backend target group"
  type        = string
  default     = "/health"
}

variable "backend_tg_interval" {
  description = "Health check interval for the backend target group"
  type        = number
  default     = 30
}

variable "backend_tg_timeout" {
  description = "Health check timeout for the backend target group"
  type        = number
  default     = 5
}

variable "backend_tg_healthy_threshold" {
  description = "Number of successful health checks for the backend target group"
  type        = number
  default     = 2
}

variable "backend_tg_unhealthy_threshold" {
  description = "Number of failed health checks for the backend target group"
  type        = number
  default     = 2
}

variable "backend_tg_matcher" {
  description = "HTTP code matcher for the backend target group"
  type        = string
  default     = "200"
}

variable "backend_tg_tag_name" {
  description = "Tag name for the backend target group"
  type        = string
  default     = "BackendTargetGroup"
}


########################## ALB Variables #############################
variable "alb_name" {
  description = "Name for the ALB"
  type        = string
  default     = "alb-web-servers-asg"
}

variable "alb_vpc_id" {
  description = "VPC for the ALB"
  type        = string
}

variable "alb_subnets" {
  description = "Subnets for the ALB"    # We need 2 Subnets for the ALB to work
  type        = list(string)
}

variable "alb_security_groups" {
  description = "SEC_Group for the ALB"
  type        = list(string)
}

variable "alb_load_balancer_type" {
  description = "Load Balancer Type"
  type        = string
  default     = "application"
}

variable "alb_internal" {
  description = "ALB - Internal or Public?"
  type        = bool
  default     = false
}

variable "alb_enable_deletion_protection" {
  description = "Delete protection for the ALB"
  type        = bool
  default     = false
}

variable "alb_tag_name" {
  description = "Tag name for the ALB"
  type        = string
  default     = "asg-web-servers-alb"
}