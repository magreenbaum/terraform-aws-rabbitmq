locals {
  cluster_name = var.name
}


data "aws_region" "current" {}

data "aws_ami" "amazon_linux_2_latest" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"] # at time of writing gp3 was not available
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.*"]
  }
}

data "aws_ami" "amazon_linux_2" {
  owners             = ["amazon"]
  most_recent        = true
  include_deprecated = true

  filter {
    name = "image-id"
    #bootstrap with latest if ami is not provided
    values = [var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2_latest.image_id]
  }
}

resource "random_password" "admin_password" {
  length  = 32
  special = false
}

resource "random_password" "rabbit_password" {
  length  = 32
  special = false
}

resource "random_password" "secret_cookie" {
  length  = 64
  special = false
}

resource "random_password" "datadog_password" {
  length  = 64
  special = false
}

data "aws_iam_policy_document" "policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy_permissions_doc" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "ec2:DescribeInstances"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:ListImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [
      aws_ssm_parameter.datadog_api_key.arn,
      aws_ssm_parameter.datadog_user_password.arn,
      aws_ssm_parameter.rabbit_admin_password.arn,
      aws_ssm_parameter.rabbit_password.arn,
      aws_ssm_parameter.secret_cookie.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      var.kms_key_arn
    ]
  }
}

resource "aws_iam_role_policy" "iam_policy" {
  name = "${local.cluster_name}-${data.aws_region.current.name}"
  role = aws_iam_role.iam_role.id

  policy = data.aws_iam_policy_document.policy_permissions_doc.json
}

resource "aws_iam_instance_profile" "iam_profile" {
  name_prefix = "${local.cluster_name}-${data.aws_region.current.name}-"
  role        = aws_iam_role.iam_role.name
}

resource "aws_iam_role" "iam_role" {
  name               = "${local.cluster_name}-${data.aws_region.current.name}"
  assume_role_policy = data.aws_iam_policy_document.policy_doc.json
  tags               = var.tags
}

resource "aws_security_group" "rabbitmq_elb" {
  name        = "${var.name}-elb"
  vpc_id      = var.vpc_id
  description = "Security Group for the rabbitmq elb"

  egress {
    description = "for the rabbitmq elb"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-vpc-no-public-egress-sgr
  }

  tags = merge(var.tags, {
    Name = "rabbitmq ${var.name} ELB"
  })
}

resource "aws_security_group" "rabbitmq_nodes" {
  name        = "${local.cluster_name}-nodes"
  vpc_id      = var.vpc_id
  description = "Security Group for the rabbitmq nodes"

  ingress {
    description = "for the rabbitmq nodes"
    protocol    = -1
    from_port   = 0
    to_port     = 0
    self        = true
  }

  ingress {
    description     = "for the rabbitmq nodes"
    protocol        = "tcp"
    from_port       = 5672
    to_port         = 5672
    security_groups = [aws_security_group.rabbitmq_elb.id]
  }

  ingress {
    description     = "management port"
    protocol        = "tcp"
    from_port       = 15672
    to_port         = 15672
    security_groups = [aws_security_group.rabbitmq_elb.id]
  }

  egress {
    description = "for the rabbitmq nodes"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0

    cidr_blocks = ["0.0.0.0/0", ] #tfsec:ignore:aws-vpc-no-public-egress-sgr
  }

  tags = merge(var.tags, {
    Name = "rabbitmq ${var.name} nodes"
  })
}

resource "aws_launch_template" "rabbitmq" {
  name_prefix   = local.cluster_name
  image_id      = data.aws_ami.amazon_linux_2.image_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  vpc_security_group_ids = flatten([
    aws_security_group.rabbitmq_nodes.id, var.nodes_additional_security_group_ids,
  ])

  user_data = base64encode(templatefile(
    "${path.module}/cloud-init.yaml",
    {
      sync_node_count  = var.max_size
      asg_name         = local.cluster_name
      region           = data.aws_region.current.name
      admin_password   = aws_ssm_parameter.rabbit_admin_password.name
      rabbit_password  = aws_ssm_parameter.rabbit_password.name
      secret_cookie    = aws_ssm_parameter.secret_cookie.name
      message_timeout  = 3 * 24 * 60 * 60 * 1000 # 3 days
      rabbitmq_image   = var.rabbitmq_image
      rabbitmq_version = join(",", regex("^.+:(.+)$", var.rabbitmq_image))
      ecr_registry_id  = var.ecr_registry_id
      dd_api_key       = aws_ssm_parameter.datadog_api_key.name
      dd_env           = var.dd_env
      dd_site          = var.dd_site
      dd_password      = aws_ssm_parameter.datadog_user_password.name
      app_name         = var.name
      region           = data.aws_region.current.name
  }))

  metadata_options {
    http_tokens = "required"
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.iam_profile.arn
  }

  block_device_mappings {
    device_name = data.aws_ami.amazon_linux_2.root_device_name
    ebs {
      volume_type           = var.instance_volume_type
      volume_size           = var.instance_volume_size
      iops                  = var.instance_volume_iops
      delete_on_termination = true
      encrypted             = var.encrypted_ebs_instance_volume
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# the autoscaling group
locals {
  autoscaling_group_tags = merge(var.tags, {
    MonitorRMQ = "enabled",
    Name       = local.cluster_name
  })
}

resource "aws_autoscaling_group" "rabbitmq" {
  name                      = local.cluster_name
  min_size                  = var.min_size
  desired_capacity          = var.desired_size
  max_size                  = var.max_size
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = "ELB"
  force_delete              = true
  load_balancers            = [aws_elb.elb.name]
  vpc_zone_identifier       = var.subnet_ids

  launch_template {
    id      = aws_launch_template.rabbitmq.id
    version = aws_launch_template.rabbitmq.latest_version
  }

  dynamic "tag" {
    for_each = local.autoscaling_group_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_elb" "elb" {
  name = "${local.cluster_name}-elb"

  listener {
    instance_port     = 5672
    instance_protocol = "tcp"
    lb_port           = 5672
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 15672
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    interval            = var.health_check_interval
    unhealthy_threshold = var.unhealthy_threshold
    healthy_threshold   = var.healthy_threshold
    timeout             = var.timeout
    target              = "TCP:5672"
  }

  subnets         = var.subnet_ids
  idle_timeout    = 3600
  internal        = true
  security_groups = flatten([aws_security_group.rabbitmq_elb.id, var.elb_additional_security_group_ids])

  access_logs {
    bucket        = var.access_log_bucket
    bucket_prefix = var.access_log_bucket_prefix
    interval      = var.access_log_interval
    enabled       = var.access_logs_enabled
  }

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}

resource "aws_ssm_parameter" "datadog_api_key" {
  name   = "/${var.name}/DATADOG_API_KEY"
  type   = "SecureString"
  value  = "Add Datadog API Key Here"
  key_id = var.kms_key_arn

  lifecycle {
    ignore_changes = [value]
  }
  tags = var.tags
}

resource "aws_ssm_parameter" "datadog_user_password" {
  name   = "/${var.name}/DATADOG_PASSWORD"
  type   = "SecureString"
  value  = random_password.datadog_password.result
  key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "rabbit_admin_password" {
  name   = "/${var.name}/ADMIN_PASSWORD"
  type   = "SecureString"
  value  = random_password.admin_password.result
  key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "rabbit_password" {
  name   = "/${var.name}/RABBIT_PASSWORD"
  type   = "SecureString"
  value  = random_password.rabbit_password.result
  key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "secret_cookie" {
  name   = "/${var.name}/SECRET_COOKIE"
  type   = "SecureString"
  value  = random_password.secret_cookie.result
  key_id = var.kms_key_arn

  tags = var.tags
}
