locals {
  s3_bucket_arn = var.session_manager_s3_logging_bucket_arn != "" ? var.session_manager_s3_logging_bucket_arn : "arn:aws:s3:::${var.access_log_bucket}"
}
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count      = var.aws_session_manager_enabled ? 1 : 0
  policy_arn = aws_iam_policy.ssm_managed_instances[count.index].arn
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_policy" "ssm_managed_instances" {
  count  = var.aws_session_manager_enabled ? 1 : 0
  name   = "${local.cluster_name}-ssm-management-${data.aws_region.current.name}"
  policy = data.aws_iam_policy_document.ssm_managed_instances[count.index].json
}

data "aws_iam_policy_document" "ssm_managed_instances" {
  count = var.aws_session_manager_enabled ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = var.session_manager_s3_logging ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        local.s3_bucket_arn
      ]
    }
  }
  dynamic "statement" {
    for_each = var.session_manager_s3_logging ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:GetEncryptionConfiguration"
      ]
      resources = ["*"]
    }
  }
  dynamic "statement" {
    for_each = length(var.session_manager_kms_key_arn) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt"
      ]
      resources = [
        var.session_manager_kms_key_arn
      ]
    }
  }
  dynamic "statement" {
    for_each = length(var.session_manager_cloudwatch_log_group_arn) > 0 || var.session_manager_s3_logging ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:GenerateDataKey"
      ]
      resources = [
        var.session_manager_kms_key_arn
      ]
    }
  }
  dynamic "statement" {
    for_each = length(var.session_manager_cloudwatch_log_group_arn) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      resources = [
        "*"
      ]
    }
  }
}

