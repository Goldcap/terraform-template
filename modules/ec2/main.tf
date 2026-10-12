data "aws_ssm_parameter" "al2023_ami" {
  count = var.ami_id == null ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "this" {
  ami           = coalesce(var.ami_id, try(data.aws_ssm_parameter.al2023_ami[0].value, null))
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = var.associate_public_ip_address
  source_dest_check           = var.source_dest_check

  key_name             = var.key_name
  iam_instance_profile = var.iam_policy_json == null ? null : aws_iam_instance_profile.this[0].name

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = var.name }

  lifecycle {
    # Don't replace the instance every time AWS publishes a new AMI.
    ignore_changes = [ami]
  }
}
