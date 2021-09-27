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
