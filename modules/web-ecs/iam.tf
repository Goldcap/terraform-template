data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Container instances: AWS's managed policy for the ECS agent (register with
# the cluster, poll for tasks, pull images, send logs).
resource "aws_iam_role" "instances" {
  name        = "${var.name}-ecs-instance"
  description = "Role for the ${var.name} ECS container instances (ECS agent)."

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "instances_ecs_agent" {
  role       = aws_iam_role.instances.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instances" {
  name = "${var.name}-ecs-instance"
  role = aws_iam_role.instances.name
}

# Task execution role: used by ECS (not the container) to write logs and to
# resolve the task definition's Secrets Manager references at task start.
data "aws_iam_policy_document" "task_execution" {
  statement {
    sid    = "WriteContainerLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.nginx.arn}:*"]
  }

  statement {
    sid       = "ReadAdminCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.admin_secret_arn]
  }
}

resource "aws_iam_role" "task_execution" {
  name        = "${var.name}-ecs-task-execution"
  description = "ECS task execution role for the ${var.name} nginx service."

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "logs-and-admin-secret"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution.json
}

# No task role: the nginx container makes no AWS API calls, so it gets no
# AWS credentials at all.
