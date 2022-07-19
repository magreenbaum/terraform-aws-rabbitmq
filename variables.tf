variable "vpc_id" {
}

variable "ssh_key_name" {
  type        = string
  description = "The ssh key to provide the instance to use for ssh login"
}

variable "name" {
  type        = string
  description = "The name of the RabbitMQ cluster"
  default     = "main"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID to use for the ec2 instance"
  default     = ""
}

variable "min_size" {
  type        = number
  description = "Minimum number of RabbitMQ nodes"
  default     = 2
}

variable "desired_size" {
  type        = number
  description = "Desired number of RabbitMQ nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of RabbitMQ nodes"
  default     = 2
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for RabbitMQ nodes"
}

variable "nodes_additional_security_group_ids" {
  type        = list(string)
  description = "List of additional node security group ids"
  default     = []
}

variable "elb_additional_security_group_ids" {
  type        = list(string)
  description = "List of additional ELB security group ids"
  default     = []
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type to use"
  default     = "m5.large"
}

variable "instance_volume_type" {
  type        = string
  description = "The instance volume type to use (standard, gp2, gp3, st1, sc1, io1)"
  default     = "standard"
}

variable "instance_volume_size" {
  type        = number
  description = "The size of the instance volume in gigabytes"
  default     = 0
}

variable "instance_volume_iops" {
  type        = number
  description = "The amount of provisioned iops"
  default     = 0
}

variable "rabbitmq_image" {
  type        = string
  description = "The Rabbitmq docker image"
}

variable "ecr_registry_id" {
  type        = string
  description = "The ECR registry ID"
}

variable "access_log_bucket" {
  type        = string
  description = "optional bucket name to use for access logs"
  default     = "bucketname"
}

variable "access_log_bucket_prefix" {
  type        = string
  description = "optional prefix to use for access logs"
  default     = ""
}

variable "access_log_interval" {
  type        = number
  description = "How often for the ELB to publish access logs in minutes"
  default     = 60
}

variable "access_logs_enabled" {
  type        = bool
  description = "Whether or not to enable access logging on the ELB"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Optional additional Tags to add onto resources this module creates"
  default     = {}
}

variable "encrypted_ebs_instance_volume" {
  type        = bool
  description = "Whether to encrypt the instance ebs volume"
  default     = true
}

variable "dd_env" {
  type        = string
  description = "The environment the app is running in"
}

variable "dd_site" {
  type        = string
  description = "The Datadog site url"
}

variable "kms_key_arn" {
  type        = string
  description = "The KMS key arn to use for encrypting and decrypting SSM parameters"
}

variable "health_check_grace_period" {
  type        = number
  description = "The ASG health check grace period"
  default     = 400
}

variable "health_check_interval" {
  type        = number
  description = "The ELB health check interval in seconds"
  default     = 30
}

variable "unhealthy_threshold" {
  type        = number
  description = "The ELB health check unhealthy threshold count"
  default     = 10
}

variable "healthy_threshold" {
  type        = number
  description = "The ELB health check healthy threshold count"
  default     = 2
}

variable "timeout" {
  type        = number
  description = "The ELB health check length of time before timeout in seconds"
  default     = 3
}

variable "aws_session_manager_enabled" {
  type        = bool
  description = "Whether or not the ec2 instances in this cluster should allow session manager permissions"
  default     = false
}