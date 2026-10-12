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
