# Not KMS-encrypted: CloudWatch alarms can't publish to a topic encrypted with
# the AWS managed SNS key, and a customer managed key costs $1/month. Alarm
# notifications contain no sensitive data.
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
