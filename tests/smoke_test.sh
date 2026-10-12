#!/usr/bin/env bash
# Post-deployment smoke tests for the Hello World stack.
#
# Usage:
#   tests/smoke_test.sh [terraform-dir]      # default: environments/dev
#
# Reads everything it needs from `terraform output` in the given directory and
# checks every enabled web platform (EC2 Auto Scaling Group, ECS and/or EKS).
#
# Requires: terraform, curl, jq, and the AWS CLI with read access to the account.

# shellcheck disable=SC2016  # backticks in --query strings are JMESPath literals
set -euo pipefail

TF_DIR="${1:-environments/dev}"
OUTPUTS=$(terraform -chdir="$TF_DIR" output -json)

output() {
  jq -r --arg name "$1" '.[$name].value // empty' <<<"$OUTPUTS"
}

ALB_DNS_NAME=$(output alb_dns_name)
ADMIN_SECRET_ARN=$(output admin_secret_arn)
ASG_NAME=$(output autoscaling_group_name)
ECS_CLUSTER=$(output ecs_cluster_name)
ECS_SERVICE=$(output ecs_service_name)
EKS_CLUSTER=$(output eks_cluster_name)
EKS_NODE_GROUP=$(output eks_node_group_name)
PLATFORMS=$(jq -r '.enabled_platforms.value[]' <<<"$OUTPUTS")
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

alarm_notifies_sns() {
  jq -e '.AlarmActions | any(startswith("arn:aws:sns:"))' <<<"$1" >/dev/null
}

no_public_ips() {
  # shellcheck disable=SC2086  # instance IDs are intentionally word-split
  test -z "$(aws ec2 describe-instances --instance-ids $1 \
    --query 'Reservations[].Instances[?PublicIpAddress!=`null`].PublicIpAddress' --output text)"
}

instance_types_are() {
  # shellcheck disable=SC2086
  test "$(aws ec2 describe-instances --instance-ids $1 \
    --query 'Reservations[].Instances[].InstanceType' --output text | tr '\t' '\n' | sort -u)" = "$2"
}

echo "Smoke testing ${BASE_URL} (region ${AWS_REGION}, platforms: $(echo "$PLATFORMS" | xargs))"

# --- Web application via the ALB ------------------------------------------------
# A fresh deployment can take a few minutes for start-up to finish and targets
# to pass health checks, so wait for the first successful response.
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
  # Several requests, so every platform behind the load balancer is exercised.
  ADMIN_CODES=$(for _ in $(seq 1 10); do http_status -u "${ADMIN_USER}:${ADMIN_PASS}" "${BASE_URL}/admin/"; echo; done | sort -u | xargs)
  check "GET /admin/ with Secrets Manager credentials returns 200 on every platform (got: ${ADMIN_CODES})" test "$ADMIN_CODES" = "200"
  unset ADMIN_PASS
else
  echo "  SKIP  /admin/ login (no permission to read ${ADMIN_SECRET_ARN})"
fi

# Every enabled platform must actually be serving traffic through the ALB.
SERVED_BY=$(for _ in $(seq 1 30); do curl -s --max-time 10 "${BASE_URL}/" | grep -o 'Served by [A-Z0-9]*' || true; done | sort | uniq -c)
for platform in $PLATFORMS; do
  label=$(tr '[:lower:]' '[:upper:]' <<<"$platform")
  check "Platform ${platform} is serving requests through the ALB" grep -q "Served by ${label}" <<<"$SERVED_BY"
done

# --- Infrastructure -------------------------------------------------------------
echo "Infrastructure:"
for platform in $PLATFORMS; do
  TARGET_GROUP_ARN=$(jq -r --arg p "$platform" '.target_group_arns.value[$p]' <<<"$OUTPUTS")
  HEALTH=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" --query 'TargetHealthDescriptions[].TargetHealth.State' --output text | tr '\t' '\n')
  HEALTHY=$(grep -c '^healthy$' <<<"$HEALTH" || true)
  UNHEALTHY=$(grep -vc '^healthy$' <<<"$HEALTH" || true)
  check "${platform}: all load balancer targets healthy (${HEALTHY} healthy, ${UNHEALTHY} not)" test "$UNHEALTHY" = "0" -a "$HEALTHY" -ge 1
done

if [ -n "$ASG_NAME" ]; then
  ASG_JSON=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" --query 'AutoScalingGroups[0]')
  check "ec2: Auto Scaling Group min size is 1" test "$(jq -r .MinSize <<<"$ASG_JSON")" = "1"
  check "ec2: Auto Scaling Group max size is 3" test "$(jq -r .MaxSize <<<"$ASG_JSON")" = "3"
  POLICY_METRIC=$(aws autoscaling describe-policies --auto-scaling-group-name "$ASG_NAME" \
    --query 'ScalingPolicies[0].TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType' --output text)
  check "ec2: Auto Scaling Group scales on CPU" test "$POLICY_METRIC" = "ASGAverageCPUUtilization"
  INSTANCE_IDS=$(jq -r '.Instances[].InstanceId' <<<"$ASG_JSON" | xargs)
  check "ec2: web servers have no public IP addresses" no_public_ips "$INSTANCE_IDS"
  check "ec2: web servers are t2.micro" instance_types_are "$INSTANCE_IDS" "t2.micro"
fi

if [ -n "$ECS_SERVICE" ]; then
  SERVICE_JSON=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0]')
  check "ecs: service is ACTIVE with at least 1 running task" test "$(jq -r '.status' <<<"$SERVICE_JSON")" = "ACTIVE" -a "$(jq -r '.runningCount' <<<"$SERVICE_JSON")" -ge 1
  SCALING_JSON=$(aws application-autoscaling describe-scalable-targets --service-namespace ecs \
    --resource-ids "service/${ECS_CLUSTER}/${ECS_SERVICE}" --query 'ScalableTargets[0]')
  check "ecs: service scales between 1 and 3 tasks" test "$(jq -r '"\(.MinCapacity)-\(.MaxCapacity)"' <<<"$SCALING_JSON")" = "1-3"
  SCALING_METRIC=$(aws application-autoscaling describe-scaling-policies --service-namespace ecs \
    --resource-id "service/${ECS_CLUSTER}/${ECS_SERVICE}" \
    --query 'ScalingPolicies[0].TargetTrackingScalingPolicyConfiguration.PredefinedMetricSpecification.PredefinedMetricType' --output text)
  check "ecs: service scales on CPU" test "$SCALING_METRIC" = "ECSServiceAverageCPUUtilization"
  TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition "$(jq -r .taskDefinition <<<"$SERVICE_JSON")" --query 'taskDefinition')
  check "ecs: admin credentials are injected from Secrets Manager" \
    test "$(jq -r '[.containerDefinitions[0].secrets[].valueFrom | startswith("arn:aws:secretsmanager:")] | all' <<<"$TASK_DEFINITION")" = "true"
  CONTAINER_INSTANCES=$(aws ecs list-container-instances --cluster "$ECS_CLUSTER" --query 'containerInstanceArns' --output text)
  # shellcheck disable=SC2086
  ECS_INSTANCE_IDS=$(aws ecs describe-container-instances --cluster "$ECS_CLUSTER" --container-instances $CONTAINER_INSTANCES \
    --query 'containerInstances[].ec2InstanceId' --output text | xargs)
  check "ecs: container instances have no public IP addresses" no_public_ips "$ECS_INSTANCE_IDS"
  check "ecs: container instances are t2.micro" instance_types_are "$ECS_INSTANCE_IDS" "t2.micro"
fi

if [ -n "$EKS_CLUSTER" ]; then
  check "eks: cluster is ACTIVE" test "$(aws eks describe-cluster --name "$EKS_CLUSTER" --query 'cluster.status' --output text)" = "ACTIVE"
  NODE_GROUP_JSON=$(aws eks describe-nodegroup --cluster-name "$EKS_CLUSTER" --nodegroup-name "$EKS_NODE_GROUP" --query 'nodegroup')
  check "eks: node group is ACTIVE" test "$(jq -r .status <<<"$NODE_GROUP_JSON")" = "ACTIVE"
  check "eks: node group scales between 1 and 3 nodes" test "$(jq -r '"\(.scalingConfig.minSize)-\(.scalingConfig.maxSize)"' <<<"$NODE_GROUP_JSON")" = "1-3"
  NODE_ASG=$(jq -r '.resources.autoScalingGroups[0].name' <<<"$NODE_GROUP_JSON")
  NODE_IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$NODE_ASG" --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text | xargs)
  check "eks: nodes have no public IP addresses" no_public_ips "$NODE_IDS"
  check "eks: nodes are t3.small" instance_types_are "$NODE_IDS" "t3.small"
  check "eks: nginx gets Secrets Manager access via Pod Identity" \
    test "$(aws eks list-pod-identity-associations --cluster-name "$EKS_CLUSTER" --namespace hello-world --service-account nginx --query 'length(associations)' --output text)" = "1"
fi

for alarm in $(jq -r '.cpu_alarm_names.value[]' <<<"$OUTPUTS"); do
  ALARM_JSON=$(aws cloudwatch describe-alarms --alarm-names "$alarm" --query 'MetricAlarms[0]')
  check "${alarm}: threshold is 70%" test "$(jq -r .Threshold <<<"$ALARM_JSON")" = "70.0"
  check "${alarm}: notifies an SNS topic" alarm_notifies_sns "$ALARM_JSON"
done

echo
echo "${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ]
