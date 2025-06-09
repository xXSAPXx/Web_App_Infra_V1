
##########################################
# BASTION HOST VARIABLES 
##########################################

variable "ami_id" {
  description = "AMI ID to launch the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance in"
  type        = string
}

variable "bastion_sec_group_ids" {
  type        = list(string)
  description = "Sec_group id for the Bastion EC2"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "user_data_path" {
  description = "Path to the user data template file"
  type        = string
}

variable "volume_size" {
  description = "EBS Volume GBs Size"
  type        = number
  default     = 10
}

variable "volume_type" {
  description = "EBS Volume Type"
  type        = string
  default     = "gp2"
}

variable "bastion_host_tag_name" {
  description = "Tags to apply to the EC2 instance"
  type        = map(string)
  default     = {
    Name = "Bastion-Prometheus-IaC"
  }
}



