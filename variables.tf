variable "enabled" {
  description = "If set to false, the module will do nothing. This exists because there can be no `count` meta-parameter for a module"
  default     = "true"
}

variable "local_prefix" {}
variable "global_prefix" {}
variable "name" {}

variable "region" {}

variable "tags" {
  type = map(string)
}

variable "versioning" {
  default = "false"
}

variable "sns_topic" {
  description = "Whether to create an SNS topic and publish S3 object creations to it"
  default     = false
}

variable "readonly_accounts" {
  description = "List of other AWS accounts which should get read-only access to the bucket - and subscribe access to its SNS topic"
  type        = list(string)
  default     = []
}

variable "write_accounts" {
  description = "List of other AWS accounts which should get write access to the bucket"
  type        = list(string)
  default     = []
}

variable "lifecycle_rules" {
  type    = list(string)
  default = []
}

variable "protect" {
  description = "Whether to protect the bucket (and the SNS topic if created) from deletion"
  default     = false
}

variable "account_id" {
  description = "AWS account ID. Only needed if sns_topic = true AND protect = true"
  default     = ""
}
