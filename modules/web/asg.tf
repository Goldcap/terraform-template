data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  cloudwatch_agent_config = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
      omit_hostname               = true
    }
    metrics = {
      namespace = var.metrics_namespace
      # One metric per Auto Scaling Group (not per instance) keeps custom
      # metric count - and cost - flat as the group scales.
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
      }
      metrics_collected = {
        mem = {
          measurement = ["mem_used_percent"]
        }
      }
    }
  })
}

resource "aws_launch_template" "web" {
  name_prefix = "${var.name}-web-"
  description = "Launch template for the ${var.name} web servers."

  # A new AMI creates a new launch template version, which triggers a rolling
  # instance refresh on the next apply - patched instances, no in-place drift.
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.web.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
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
      volume_size           = 8
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region                  = data.aws_region.current.region
    admin_secret_arn        = aws_secretsmanager_secret.admin.arn
    health_check_path       = var.health_check_path
    cloudwatch_agent_config = local.cloudwatch_agent_config
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-web" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-web" }
  }

  update_default_version = true

  # Instances read the secret at boot, so it must have a value first.
  depends_on = [aws_secretsmanager_secret_version.admin]
}

resource "aws_autoscaling_group" "web" {
  name = "${var.name}-web"

  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.web.arn]

  min_size = var.min_size
  max_size = var.max_size
  # desired_capacity is intentionally unset so Terraform doesn't fight the
  # scaling policy; the group starts at min_size.

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  # Replace instances the load balancer reports as unhealthy, not just ones
  # that fail EC2 status checks. The grace period covers cloud-init.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Wait for new instances to pass load balancer health checks on apply.
  min_elb_capacity = var.min_size

  # Launch-before-terminate rolling replacement whenever the launch template
  # changes, so a single-instance group never drops to zero.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 300
      auto_rollback          = true
    }
  }

  # Group metrics are free and back the dashboard.
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = true
  }
}

# Scale out/in to hold average CPU at the target. AWS creates and manages the
# underlying CloudWatch alarms for this policy.
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name}-web-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_utilization
  }
}
