

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/24"
}


variable "vpc_name" {
  description = "The name for the VPC."
  type        = string
  default     = "App_VPC_IaC"
}


variable "internet_gateway_name" {
  description = "The name for the IG."
  type        = string
  default     = "Internet_Gateway_IaC"
}


variable "public_subnet_1_cidr" {
  description = "A list of CIDR blocks for the public subnets."
  type        = string
  default     = "10.0.0.0/28"
}


variable "public_subnet_2_cidr" {
  description = "A list of CIDR blocks for the public subnets."
  type        = string
  default     = "10.0.0.16/28"
}


variable "private_subnet_1_cidr" {
  description = "A list of CIDR blocks for the private subnets."
  type        = string
  default     = "10.0.0.32/28"
}


variable "private_subnet_2_cidr" {
  description = "A list of CIDR blocks for the private subnets."
  type        = string
  default     = "10.0.0.48/28"
}


variable "availability_zone_1" {
  description = "A list of availability zones to deploy the subnets into."
  type        = string
  default     = "us-east-1a"
}


variable "availability_zone_2" {
  description = "A list of availability zones to deploy the subnets into."
  type        = string
  default     = "us-east-1b"
}


variable "nat_gateway_public_subnet_id" {
  description = "The Public Subnet_ID for the NAT_GATEWAY."
  type        = string
  default     = "aws_subnet.public_subnet_1.id"
}


variable "rds_subnet_group_name" {
  description = "The name for the RDS Subnet Group."
  type        = string
  default     = "App_DB_Subnet_Group_IaC"
}


variable "private_zone_name" {
  description = "The name of the private Route53 zone."
  type        = string
  default     = "internal.xxsapxx.local"
}