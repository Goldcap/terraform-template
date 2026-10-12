data "aws_region" "current" {}

# Ties destroy order to the private subnets' outbound path: anything that
# depends on this is destroyed before the NAT route or gateway behind it.
resource "terraform_data" "egress" {
  input = var.egress_dependency
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/${var.name}/nginx"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.name}-nginx"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = var.container_image
      essential = true
      cpu       = var.task_cpu
      memory    = var.task_memory

      # hostPort 0 = dynamic host port, so several tasks can share an instance.
      portMappings = [{ containerPort = 80, hostPort = 0, protocol = "tcp" }]

      # Injected by ECS from Secrets Manager at task start. They never appear in
      # the task definition, in Terraform state or in the container's command.
      secrets = [
        { name = "ADMIN_USERNAME", valueFrom = "${var.admin_secret_arn}:username::" },
        { name = "ADMIN_PASSWORD", valueFrom = "${var.admin_secret_arn}:password::" }
      ]

      entryPoint = ["/bin/sh", "-c"]
      command = [templatefile("${path.module}/templates/start_nginx.sh.tftpl", {
        health_check_path = var.health_check_path
      })]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1${var.health_check_path} || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "nginx" {
  name            = "${var.name}-nginx"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = var.min_size

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "nginx"
    container_port   = 80
  }

  health_check_grace_period_seconds = 60

  # Roll back automatically if a new task definition never becomes healthy.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  # Apply only finishes once the service is healthy, so the CI smoke test
  # runs against a working deployment.
  wait_for_steady_state = true

  # Destroy order matters: the ECS agent needs its IAM policy, HTTPS egress
  # and the NAT path until the service has fully drained, or it disconnects
  # and the service is stuck in DRAINING (the delete times out after 20m).
  depends_on = [
    aws_ecs_cluster_capacity_providers.this,
    aws_iam_role_policy_attachment.instances_ecs_agent,
    aws_iam_role_policy.task_execution,
    aws_vpc_security_group_egress_rule.https,
    terraform_data.egress,
  ]

  lifecycle {
    # Owned by the service auto scaling policy below.
    ignore_changes = [desired_count]
  }
}

resource "aws_lb_target_group" "ecs" {
  name        = "${var.name}-ecs"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-ecs" }

  # Shared-ALB ordering: the listener forwards to this group, so when a
  # platform is switched off the listener must be updated BEFORE the group is
  # deleted. create_before_destroy makes Terraform order it that way; without
  # it the delete runs first and fails with ResourceInUse. (A replacement of
  # this group would need a new name, since names are unique.)
  lifecycle {
    create_before_destroy = true
  }
}

# Task count: hold average service CPU at the target, between min and max.
# The capacity provider then adds or removes instances to fit the tasks.
resource "aws_appautoscaling_target" "nginx" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.nginx.name}"
  min_capacity       = var.min_size
  max_capacity       = var.max_size
}

resource "aws_appautoscaling_policy" "cpu_target_tracking" {
  name               = "${var.name}-nginx-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.nginx.service_namespace
  scalable_dimension = aws_appautoscaling_target.nginx.scalable_dimension
  resource_id        = aws_appautoscaling_target.nginx.resource_id

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
