
# Configure Terraform Remote Backend: 
terraform {
  backend "s3" {
    bucket       = "value"
    key          = "value"
    region       = "value"
    encrypt      = true
    use_lockfile = true
  }
}