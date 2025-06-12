
# Configure Terraform Remote Backend: 
terraform {
  backend "s3" {
    bucket       = "terraform-main-backend-tfstate"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
