
#####################################################################################
# IAM FOR PROMETHEUS AUTO SERVICE DISCOVERY 
#####################################################################################

# Create the IAM policy for the Prometheus Server:
resource "aws_iam_policy" "prometheus" {
  name = "prometheus-instance-policy"

  description = "Policy for Prometheus EC2 instance to allow EC2, ELB, CloudWatch, and ASG reads"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:GetSecurityGroupsForVpc"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "elasticloadbalancing:Describe*",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:Describe*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "autoscaling:Describe*",
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "prometheus-iam-policy"
  }
}


# Create the IAM Role for the Prometheus Server: 
resource "aws_iam_role" "prometheus" {
  name = "prometheus-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "prometheus-ec2-role"
  }
}


# Create the IAM attachment for the Prometheus Server:
resource "aws_iam_role_policy_attachment" "prometheus" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.prometheus.arn
}


# Create the IAM instance profile for the Prometheus Server:
resource "aws_iam_instance_profile" "prometheus" {
  name = "prometheus-instance-profile"
  role = aws_iam_role.prometheus.name
}




#####################################################################################
# IAM FOR AUTO DNS(Route53) REGISTRATION for the ASG Servers:
#####################################################################################