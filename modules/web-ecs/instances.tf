data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix = "${var.name}-ecs-"
  description = "Launch template for the ${var.name} ECS container instances."

  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.instances.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.instances.arn
  }

  # IMDSv2 only, and a hop limit of 1 so containers on the bridge network
  # cannot reach the instance metadata service (and the instance role).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Detailed (1-minute) monitoring is billed; basic 5-minute metrics are free.
  monitoring {
    enabled = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = 30 # Minimum size of the ECS-optimized AMI snapshot
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    cat >> /etc/ecs/ecs.config <<'CONFIG'
    ECS_CLUSTER=${aws_ecs_cluster.this.name}
    ECS_ENABLE_CONTAINER_METADATA=true
    CONFIG
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-ecs" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-ecs" }
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "ecs" {
  name = "${var.name}-ecs"

  vpc_zone_identifier = var.private_subnet_ids

  min_size = var.min_size
  max_size = var.max_size
  # desired_capacity is owned by the ECS capacity provider's managed scaling.

  launch_template {
    id      = aws_launch_template.ecs.id
    version = aws_launch_template.ecs.latest_version
  }

  health_check_type         = "EC2"
  health_check_grace_period = 120

  # Required by managed termination protection: ECS decides which instances
  # are safe to remove.
  protect_from_scale_in = true

  # Scale-in protection would otherwise block `terraform destroy`.
  force_delete = true

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
