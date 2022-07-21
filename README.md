# Dead simple Terraform configuration for creating RabbitMQ cluster on AWS.

## What it does ?

1. Uses [official](https://hub.docker.com/_/rabbitmq/) RabbitMQ docker image.
1. Creates `N` nodes in `M` subnets
1. Creates Autoscaling Group and ELB to load balance nodes
1. Makes sure nodes can talk to each other and create cluster
1. Make sure new nodes attempt to join the cluster at startup
1. Configures `/` vhost queues in High Available (Mirrored) mode with automatic synchronization (`"ha-mode":"all", "ha-sync-mode":"3"`)
1. Installs and configures Datadog Agent to gather metrics and logs for RabbitMQ


<p align="center">
<img src=".github/chart2.png" width="600">
</p>


## How to use it ?
Copy and paste into your Terraform configuration:
```
module "rabbitmq" {
  source                            = "smartrent/rabbitmq/aws"
  vpc_id                            = var.vpc_id
  ssh_key_name                      = var.ssh_key_name
  subnet_ids                        = var.subnet_ids
  elb_additional_security_group_ids = [var.cluster_security_group_id]
  min_size                          = "3"
  max_size                          = "3"
  desired_size                      = "3"
  dd_env                            = var.env_name
  dd_site                           = var.datadog_site
  kms_key_arn                       = var.kms_key_id
  ecr_registry_id                   = var.ecr_registry_id
  rabbitmq_image                    = var.rabbitmq_image
}
```

then run `terraform init`, `terraform plan` and `terraform apply`.

Are 3 node not enough ? Update sizes to `5` and run `terraform apply` again,
it will update Autoscaling Group and add `2` nodes more. Dead simple.

Node becomes unresponsive ? Autoscaling group and ELB Health Checks will automatically replace it with new one, without data loss.

Note: The VPC must have `enableDnsHostnames` = `true` and `enableDnsSupport` = `true` for the private DNS names to be resolvable for the nodes to connect to each other.   


## Debugging
If you can SSH onto one of the nodes you can run: 
`docker exec rabbitmq rabbitmqctl cluster_status` to see the cluster status of that node.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
README.md updated successfully
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.rabbitmq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_elb.elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elb) | resource |
| [aws_iam_instance_profile.iam_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.ssm_managed_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_configuration.rabbitmq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration) | resource |
| [aws_security_group.rabbitmq_elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rabbitmq_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.datadog_user_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.rabbit_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.rabbit_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.secret_cookie](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [random_password.admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.datadog_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.rabbit_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.secret_cookie](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_ami_ids.amazon-linux-2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_iam_policy_document.policy_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.policy_permissions_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ssm_managed_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_log_bucket"></a> [access\_log\_bucket](#input\_access\_log\_bucket) | optional bucket name to use for access logs | `string` | `"bucketname"` | no |
| <a name="input_access_log_bucket_prefix"></a> [access\_log\_bucket\_prefix](#input\_access\_log\_bucket\_prefix) | optional prefix to use for access logs | `string` | `""` | no |
| <a name="input_access_log_interval"></a> [access\_log\_interval](#input\_access\_log\_interval) | How often for the ELB to publish access logs in minutes | `number` | `60` | no |
| <a name="input_access_logs_enabled"></a> [access\_logs\_enabled](#input\_access\_logs\_enabled) | Whether or not to enable access logging on the ELB | `bool` | `false` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | The AMI ID to use for the ec2 instance | `string` | `""` | no |
| <a name="input_aws_session_manager_enabled"></a> [aws\_session\_manager\_enabled](#input\_aws\_session\_manager\_enabled) | Whether or not the ec2 instances in this cluster should allow session manager permissions | `bool` | `false` | no |
| <a name="input_dd_env"></a> [dd\_env](#input\_dd\_env) | The environment the app is running in | `string` | n/a | yes |
| <a name="input_dd_site"></a> [dd\_site](#input\_dd\_site) | The Datadog site url | `string` | n/a | yes |
| <a name="input_desired_size"></a> [desired\_size](#input\_desired\_size) | Desired number of RabbitMQ nodes | `number` | `2` | no |
| <a name="input_ecr_registry_id"></a> [ecr\_registry\_id](#input\_ecr\_registry\_id) | The ECR registry ID | `string` | n/a | yes |
| <a name="input_elb_additional_security_group_ids"></a> [elb\_additional\_security\_group\_ids](#input\_elb\_additional\_security\_group\_ids) | List of additional ELB security group ids | `list(string)` | `[]` | no |
| <a name="input_encrypted_ebs_instance_volume"></a> [encrypted\_ebs\_instance\_volume](#input\_encrypted\_ebs\_instance\_volume) | Whether to encrypt the instance ebs volume | `bool` | `true` | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | The ASG health check grace period | `number` | `400` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | The ELB health check interval in seconds | `number` | `30` | no |
| <a name="input_healthy_threshold"></a> [healthy\_threshold](#input\_healthy\_threshold) | The ELB health check healthy threshold count | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The EC2 instance type to use | `string` | `"m5.large"` | no |
| <a name="input_instance_volume_iops"></a> [instance\_volume\_iops](#input\_instance\_volume\_iops) | The amount of provisioned iops | `number` | `0` | no |
| <a name="input_instance_volume_size"></a> [instance\_volume\_size](#input\_instance\_volume\_size) | The size of the instance volume in gigabytes | `number` | `0` | no |
| <a name="input_instance_volume_type"></a> [instance\_volume\_type](#input\_instance\_volume\_type) | The instance volume type to use (standard, gp2, gp3, st1, sc1, io1) | `string` | `"standard"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The KMS key arn to use for encrypting and decrypting SSM parameters | `string` | n/a | yes |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of RabbitMQ nodes | `number` | `2` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of RabbitMQ nodes | `number` | `2` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the RabbitMQ cluster | `string` | `"main"` | no |
| <a name="input_nodes_additional_security_group_ids"></a> [nodes\_additional\_security\_group\_ids](#input\_nodes\_additional\_security\_group\_ids) | List of additional node security group ids | `list(string)` | `[]` | no |
| <a name="input_rabbitmq_image"></a> [rabbitmq\_image](#input\_rabbitmq\_image) | The Rabbitmq docker image | `string` | n/a | yes |
| <a name="input_session_manager_cloudwatch_log_group_arn"></a> [session\_manager\_cloudwatch\_log\_group\_arn](#input\_session\_manager\_cloudwatch\_log\_group\_arn) | The cloudwatch log group arn to send session manager logs to if sending to cloudwatch logs | `string` | `""` | no |
| <a name="input_session_manager_kms_key_arn"></a> [session\_manager\_kms\_key\_arn](#input\_session\_manager\_kms\_key\_arn) | The kms key arn to use for session manager session encryption | `string` | `""` | no |
| <a name="input_session_manager_s3_logging"></a> [session\_manager\_s3\_logging](#input\_session\_manager\_s3\_logging) | Whether to send session manager logs to s3 | `bool` | `false` | no |
| <a name="input_session_manager_s3_logging_bucket_arn"></a> [session\_manager\_s3\_logging\_bucket\_arn](#input\_session\_manager\_s3\_logging\_bucket\_arn) | The s3 bucket arn to send session manager logs to is sending to s3 bucket | `string` | `""` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | The ssh key to provide the instance to use for ssh login | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets for RabbitMQ nodes | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Optional additional Tags to add onto resources this module creates | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | The ELB health check length of time before timeout in seconds | `number` | `3` | no |
| <a name="input_unhealthy_threshold"></a> [unhealthy\_threshold](#input\_unhealthy\_threshold) | The ELB health check unhealthy threshold count | `number` | `10` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_password"></a> [admin\_password](#output\_admin\_password) | n/a |
| <a name="output_rabbit_password"></a> [rabbit\_password](#output\_rabbit\_password) | n/a |
| <a name="output_rabbitmq_elb_dns"></a> [rabbitmq\_elb\_dns](#output\_rabbitmq\_elb\_dns) | n/a |
| <a name="output_secret_cookie"></a> [secret\_cookie](#output\_secret\_cookie) | n/a |
<!-- END_TF_DOCS -->