
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