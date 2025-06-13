
# Output the instance profile for the Prometheus Server: 
output "prometheus_server_instance_profile" {
  value = aws_iam_instance_profile.prometheus.name
}


# Output the instance profile for the ASG Web-Servers: 
output "" {
  value = aws_iam_instance_profile.asg.name
}
