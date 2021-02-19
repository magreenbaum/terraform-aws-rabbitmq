# New resources to replace the existing with region specific naming
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