
########################################################################
# Public EC2 - Jump_Host + Prometheus server:
########################################################################

resource "aws_instance" "bastion_prometheus" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.bastion_sec_group_ids
  key_name               = var.key_name
  user_data              = var.user_data_path
  iam_instance_profile   = var.iam_instance_profile


  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name = var.bastion_host_tag_name
  }

}