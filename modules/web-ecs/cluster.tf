# Container Insights is off: it is billed per metric, and the free AWS/ECS
# service metrics cover the CPU and memory monitoring this project needs.
resource "aws_ecs_cluster" "this" {
  name = "${var.name}-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# EC2 capacity provider: ECS scales the Auto Scaling Group to fit the tasks it
# needs to place (managed scaling) and never terminates an instance that is
# still running tasks (managed termination protection).
resource "aws_ecs_capacity_provider" "this" {
  name = "${var.name}-ecs"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"
    managed_draining               = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}
