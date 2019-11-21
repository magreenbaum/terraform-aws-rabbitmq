variable "vpc_id" {
}

variable "ssh_key_name" {
}

variable "name" {
  default = "main"
}

variable "min_size" {
  description = "Minimum number of RabbitMQ nodes"
  default     = 2
}

variable "desired_size" {
  description = "Desired number of RabbitMQ nodes"
  default     = 2
}

variable "max_size" {
  description = "Maximum number of RabbitMQ nodes"
  default     = 2
}

variable "subnet_ids" {
  description = "Subnets for RabbitMQ nodes"
  type        = list(string)
}

variable "nodes_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "elb_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "instance_type" {
  default = "m5.large"
}

variable "instance_volume_type" {
  default = "standard"
}

variable "instance_volume_size" {
  default = "0"
}

variable "instance_volume_iops" {
  default = "0"
}

variable "rabbitmq_image" {
  type = string
}

variable "ecr_registry_id" {
  type = string
}

variable "log_retention_in_days" {
  type    = string
  default = 365
}
variable "access_log_bucket" {
  type = string
  default = ""
  description = "optional bucket name to use for access logs"
}
variable "access_log_bucket_prefix" {
  type = string
  default = ""
  description = "optional prefix to use for access logs"
}
variable "access_log_interval" {
  type = string
  default = 60
}