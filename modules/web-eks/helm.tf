locals {
  app_namespace       = "hello-world"
  app_service_account = "nginx"
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.load_balancer_controller_chart_version

  values = [yamlencode({
    clusterName = aws_eks_cluster.this.name
    region      = data.aws_region.current.region
    vpcId       = var.vpc_id
    # Pods can't reach IMDS (hop limit 1), so everything comes from values
    # and Pod Identity.
    replicaCount = 1
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
    }
    # Only TargetGroupBinding is used; no Service/Ingress webhooks needed.
    enableServiceMutatorWebhook = false
  })]

  wait = true

  depends_on = [
    aws_eks_pod_identity_association.load_balancer_controller,
    aws_iam_role_policy.load_balancer_controller,
    aws_eks_addon.after_nodes,
  ]
}

# The site itself, packaged as a small local chart (./chart): Deployment,
# Service, HPA, SecretProviderClass and the TargetGroupBinding that registers
# the pods in the ALB target group. Destroyed before the controller, so the
# controller can deregister targets and release the binding's finalizer.
#
# Values are layered like `helm -f`, later layers winning:
#   1. chart/values.yaml                      chart defaults
#   2. var.app_values                         per-environment overrides
#   3. infrastructure wiring (below)          owned by Terraform
resource "helm_release" "app" {
  name             = "hello-world"
  namespace        = local.app_namespace
  create_namespace = true
  chart            = "${path.module}/chart"

  values = concat(var.app_values, [yamlencode({
    serviceAccountName = local.app_service_account
    adminSecretArn     = var.admin_secret_arn
    targetGroupArn     = aws_lb_target_group.eks.arn
    healthCheckPath    = var.health_check_path
  })])

  wait    = true
  timeout = 600

  depends_on = [
    helm_release.load_balancer_controller,
    aws_eks_pod_identity_association.nginx,
    aws_iam_role_policy.nginx,
    aws_vpc_security_group_ingress_rule.pods_from_alb,
  ]
}
