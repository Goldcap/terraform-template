#!/usr/bin/env bash
# Post-deployment smoke tests for the Hello World stack.
#
# Usage:
#   tests/smoke_test.sh [terraform-dir]      # default: environments/dev
#
# Values are read from `terraform output` in the given directory unless they
# are already set in the environment (as they are in CI):
#   ALB_DNS_NAME, ASG_NAME, ADMIN_SECRET_ARN, CPU_ALARM_NAME, AWS_REGION
#
# Requires: curl, jq, and the AWS CLI with read access to the account.

# shellcheck disable=SC2016  # backticks in --query strings are JMESPath literals
set -euo pipefail

TF_DIR="${1:-environments/dev}"

tf_output() {
  terraform -chdir="$TF_DIR" output -raw "$1"
}

ALB_DNS_NAME="${ALB_DNS_NAME:-$(tf_output alb_dns_name)}"
ASG_NAME="${ASG_NAME:-$(tf_output autoscaling_group_name)}"
ADMIN_SECRET_ARN="${ADMIN_SECRET_ARN:-$(tf_output admin_secret_arn)}"
CPU_ALARM_NAME="${CPU_ALARM_NAME:-$(tf_output cpu_alarm_name)}"
AWS_REGION="${AWS_REGION:-$(cut -d: -f4 <<<"$ADMIN_SECRET_ARN")}"
export AWS_REGION

BASE_URL="http://${ALB_DNS_NAME}"
PASSED=0
FAILED=0

pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

http_status() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@"
}

body_contains() {
  curl -s --max-time 10 "$1" | grep -q "$2"
}

server_header_hides_version() {
  ! curl -sI --max-time 10 "$1" | grep -qi '^server: nginx/'
}

echo "Smoke testing ${BASE_URL} (region ${AWS_REGION})"

# --- Web application via the ALB ------------------------------------------------
# A fresh deployment can take a few minutes for cloud-init to finish and the
# target to pass health checks, so wait for the first successful response.
echo "Waiting for the application to respond..."
for attempt in $(seq 1 40); do
  if curl -sf --max-time 10 "${BASE_URL}/" | grep -q "Hello, World!"; then
    break
  fi
  if [ "$attempt" -eq 40 ]; then
    echo "Application did not respond with 'Hello, World!' within 10 minutes."
    exit 1
  fi
  sleep 15
done

echo "Application:"
check "GET / returns 200" test "$(http_status "${BASE_URL}/")" = "200"
check "GET / contains 'Hello, World!'" body_contains "${BASE_URL}/" "Hello, World!"
check "GET /health returns 200" test "$(http_status "${BASE_URL}/health")" = "200"
check "GET /admin/ without credentials returns 401" test "$(http_status "${BASE_URL}/admin/")" = "401"
check "GET /admin/ with wrong credentials returns 401" test "$(http_status -u admin:wrong "${BASE_URL}/admin/")" = "401"
check "Server header does not leak the nginx version" server_header_hides_version "${BASE_URL}/"

if SECRET=$(aws secretsmanager get-secret-value --secret-id "$ADMIN_SECRET_ARN" --query SecretString --output text 2>/dev/null); then
  ADMIN_USER=$(jq -r .username <<<"$SECRET")
  ADMIN_PASS=$(jq -r .password <<<"$SECRET")
  unset SECRET
  check "GET /admin/ with Secrets Manager credentials returns 200" \
    test "$(http_status -u "${ADMIN_USER}:${ADMIN_PASS}" "${BASE_URL}/admin/")" = "200"
  unset ADMIN_PASS
else
  echo "  SKIP  /admin/ login (no permission to read ${ADMIN_SECRET_ARN})"
fi

# --- Infrastructure -------------------------------------------------------------
echo "Infrastructure:"
ASG_JSON=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" --query 'AutoScalingGroups[0]')

check "Auto Scaling Group min size is 1" test "$(jq -r .MinSize <<<"$ASG_JSON")" = "1"
check "Auto Scaling Group max size is 3" test "$(jq -r .MaxSize <<<"$ASG_JSON")" = "3"

POLICY_METRIC=$(aws autoscaling describe-policies --auto-scaling-group-name "$ASG_NAME" \
  --query 'ScalingPolicies[0].TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType' --output text)
check "Auto Scaling Group scales on CPU" test "$POLICY_METRIC" = "ASGAverageCPUUtilization"

TARGET_GROUP_ARN=$(jq -r '.TargetGroupARNs[0]' <<<"$ASG_JSON")
UNHEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'length(TargetHealthDescriptions[?TargetHealth.State!=`healthy`])' --output text)
HEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
check "All load balancer targets are healthy (${HEALTHY} healthy, ${UNHEALTHY} not)" test "$UNHEALTHY" = "0" -a "$HEALTHY" -ge 1

INSTANCE_IDS=$(jq -r '.Instances[].InstanceId' <<<"$ASG_JSON")
# shellcheck disable=SC2086
PUBLIC_IPS=$(aws ec2 describe-instances --instance-ids $INSTANCE_IDS \
  --query 'Reservations[].Instances[?PublicIpAddress!=`null`].PublicIpAddress' --output text)
check "Web servers have no public IP addresses" test -z "$PUBLIC_IPS"

# shellcheck disable=SC2086
INSTANCE_TYPES=$(aws ec2 describe-instances --instance-ids $INSTANCE_IDS \
  --query 'Reservations[].Instances[].InstanceType' --output text | tr '\t' '\n' | sort -u)
check "Web servers are t2.micro" test "$INSTANCE_TYPES" = "t2.micro"

ALARM_JSON=$(aws cloudwatch describe-alarms --alarm-names "$CPU_ALARM_NAME" --query 'MetricAlarms[0]')
check "CPU alarm threshold is 70%" test "$(jq -r .Threshold <<<"$ALARM_JSON")" = "70.0"
alarm_notifies_sns() {
  jq -e '.AlarmActions | any(startswith("arn:aws:sns:"))' <<<"$1" >/dev/null
}
check "CPU alarm notifies an SNS topic" alarm_notifies_sns "$ALARM_JSON"

echo
echo "${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ]
