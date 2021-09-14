data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_region" "current" {
}

data "aws_ami_ids" "amazon-linux-2" {
  owners = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  cluster_name = var.name
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

resource "aws_cloudwatch_log_group" "log_group" {
  name              = var.name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

data "template_file" "cloud-init" {
  template = file("${path.module}/cloud-init.yaml")

  vars = {
    sync_node_count  = var.max_size
    asg_name         = local.cluster_name
    region           = data.aws_region.current.name
    admin_password   = random_password.admin_password.result
    rabbit_password  = random_password.rabbit_password.result
    secret_cookie    = random_password.secret_cookie.result
    message_timeout  = 3 * 24 * 60 * 60 * 1000 # 3 days
    rabbitmq_image   = var.rabbitmq_image
    ecr_registry_id  = var.ecr_registry_id
    cw_log_group     = aws_cloudwatch_log_group.log_group.name
    cw_log_stream    = local.cluster_name
    dd_api_key       = aws_ssm_parameter.datadog_api_key.name
    dd_env           = var.dd_env
    dd_site          = var.dd_site
    datadog_password = aws_ssm_parameter.datadog_user_password.name
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
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.log_group.arn}:*",
      "${aws_cloudwatch_log_group.log_group.arn}:*:*"
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
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
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
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  ingress {
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
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = merge(var.tags, {
    Name = "rabbitmq ${var.name} nodes"
  })
}

resource "aws_launch_configuration" "rabbitmq" {
  name_prefix          = local.cluster_name
  image_id             = var.ami_id != "" ? var.ami_id : data.aws_ami_ids.amazon-linux-2.ids[0]
  instance_type        = var.instance_type
  key_name             = var.ssh_key_name
  security_groups      = flatten([aws_security_group.rabbitmq_nodes.id, var.nodes_additional_security_group_ids])
  iam_instance_profile = aws_iam_instance_profile.iam_profile.id
  user_data            = data.template_file.cloud-init.rendered

  root_block_device {
    volume_type           = var.instance_volume_type
    volume_size           = var.instance_volume_size
    iops                  = var.instance_volume_iops
    delete_on_termination = true
    encrypted             = var.encrypted_ebs_instance_volume
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
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.rabbitmq.name
  load_balancers            = [aws_elb.elb.name]
  vpc_zone_identifier       = var.subnet_ids

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
    interval            = 30
    unhealthy_threshold = 10
    healthy_threshold   = 2
    timeout             = 3
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
  key_id = var.kms_key_id
}

resource "aws_ssm_parameter" "datadog_user_password" {
  name   = "/${var.name}/datadog_password"
  type   = "SecureString"
  value  = random_password.datadog_password.result
  key_id = var.kms_key_id
}