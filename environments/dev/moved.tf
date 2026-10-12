# State migrations for refactors of this environment. They let existing
# deployments adopt the new module layout without recreating anything, and
# can be deleted once every copy of this environment has applied them.

# modules/bastion became the generic modules/ec2.
moved {
  from = module.bastion.aws_vpc_security_group_ingress_rule.ssh["0"]
  to   = module.bastion.aws_vpc_security_group_ingress_rule.this["ssh-0"]
}

moved {
  from = module.bastion.aws_vpc_security_group_egress_rule.to_vpc["22"]
  to   = module.bastion.aws_vpc_security_group_egress_rule.this["ssh-to-vpc"]
}

moved {
  from = module.bastion.aws_vpc_security_group_egress_rule.to_vpc["80"]
  to   = module.bastion.aws_vpc_security_group_egress_rule.this["http-to-vpc"]
}

moved {
  from = module.bastion.aws_vpc_security_group_egress_rule.https
  to   = module.bastion.aws_vpc_security_group_egress_rule.this["https"]
}

moved {
  from = module.bastion.aws_iam_role.this
  to   = module.bastion.aws_iam_role.this[0]
}

moved {
  from = module.bastion.aws_iam_role_policy.this
  to   = module.bastion.aws_iam_role_policy.this[0]
}

moved {
  from = module.bastion.aws_iam_instance_profile.this
  to   = module.bastion.aws_iam_instance_profile.this[0]
}

# The network module's NAT instance now uses modules/ec2.
moved {
  from = module.network.aws_instance.nat[0]
  to   = module.network.module.nat_instance[0].aws_instance.this
}

moved {
  from = module.network.aws_security_group.nat[0]
  to   = module.network.module.nat_instance[0].aws_security_group.this
}

moved {
  from = module.network.aws_vpc_security_group_ingress_rule.nat_from_private["10.0.10.0/24-80"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_ingress_rule.this["10.0.10.0/24-80"]
}

moved {
  from = module.network.aws_vpc_security_group_ingress_rule.nat_from_private["10.0.10.0/24-443"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_ingress_rule.this["10.0.10.0/24-443"]
}

moved {
  from = module.network.aws_vpc_security_group_ingress_rule.nat_from_private["10.0.11.0/24-80"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_ingress_rule.this["10.0.11.0/24-80"]
}

moved {
  from = module.network.aws_vpc_security_group_ingress_rule.nat_from_private["10.0.11.0/24-443"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_ingress_rule.this["10.0.11.0/24-443"]
}

moved {
  from = module.network.aws_vpc_security_group_egress_rule.nat_to_internet["80"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_egress_rule.this["80"]
}

moved {
  from = module.network.aws_vpc_security_group_egress_rule.nat_to_internet["443"]
  to   = module.network.module.nat_instance[0].aws_vpc_security_group_egress_rule.this["443"]
}

# modules/web was split into the shared modules/alb, the EC2 platform
# modules/web-asg (now optional, hence [0]) and an environment-level secret.
moved {
  from = module.web.aws_lb.this
  to   = module.alb.aws_lb.this
}

moved {
  from = module.web.aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

moved {
  from = module.web.aws_security_group.alb
  to   = module.alb.aws_security_group.alb
}

moved {
  from = module.web.aws_vpc_security_group_ingress_rule.alb_http["0.0.0.0/0"]
  to   = module.alb.aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]
}

moved {
  from = module.web.aws_secretsmanager_secret.admin
  to   = aws_secretsmanager_secret.admin
}

moved {
  from = module.web.aws_secretsmanager_secret_version.admin
  to   = aws_secretsmanager_secret_version.admin
}

moved {
  from = module.web.aws_lb_target_group.web
  to   = module.web_asg[0].aws_lb_target_group.web
}

moved {
  from = module.web.aws_vpc_security_group_egress_rule.alb_to_web
  to   = module.web_asg[0].aws_vpc_security_group_egress_rule.alb_to_web
}

moved {
  from = module.web.aws_security_group.web
  to   = module.web_asg[0].aws_security_group.web
}

moved {
  from = module.web.aws_vpc_security_group_ingress_rule.web_http_from_alb
  to   = module.web_asg[0].aws_vpc_security_group_ingress_rule.web_http_from_alb
}

moved {
  from = module.web.aws_vpc_security_group_ingress_rule.web_http_from_bastion
  to   = module.web_asg[0].aws_vpc_security_group_ingress_rule.web_http_from_bastion
}

moved {
  from = module.web.aws_vpc_security_group_ingress_rule.web_ssh_from_bastion
  to   = module.web_asg[0].aws_vpc_security_group_ingress_rule.web_ssh_from_bastion
}

moved {
  from = module.web.aws_vpc_security_group_egress_rule.web_https
  to   = module.web_asg[0].aws_vpc_security_group_egress_rule.web_https
}

moved {
  from = module.web.aws_launch_template.web
  to   = module.web_asg[0].aws_launch_template.web
}

moved {
  from = module.web.aws_autoscaling_group.web
  to   = module.web_asg[0].aws_autoscaling_group.web
}

moved {
  from = module.web.aws_autoscaling_policy.cpu_target_tracking
  to   = module.web_asg[0].aws_autoscaling_policy.cpu_target_tracking
}

moved {
  from = module.web.aws_iam_role.web
  to   = module.web_asg[0].aws_iam_role.web
}

moved {
  from = module.web.aws_iam_role_policy.web
  to   = module.web_asg[0].aws_iam_role_policy.web
}

moved {
  from = module.web.aws_iam_instance_profile.web
  to   = module.web_asg[0].aws_iam_instance_profile.web
}
