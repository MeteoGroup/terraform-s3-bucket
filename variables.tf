variable "enabled" {
  # Remove this when https://github.com/hashicorp/terraform/issues/953 is solved
  description = "If set to false, the module will do nothing. This exists because there can be no `count` meta-parameter for a module"
  type        = bool
  default     = true
}

variable "local_prefix" {}
variable "global_prefix" {}
variable "name" {}

variable "tags" {
  type = map(string)
}

variable "versioning" {
  type    = bool
  default = false
}

variable "sns_topic" {
  description = "Whether to create an SNS topic and publish S3 object creations to it"
  type        = bool
  default     = false
}

variable "read_accounts" {
  description = "List of other AWS accounts which should get read access to the bucket - and subscribe access to its SNS topic"
  type        = list(string)
  default     = []
}

variable "read_prefix" {
  description = "Prefix of object keys to restrict cross-account reads to"
  type        = string
  default     = ""
}

variable "write_accounts" {
  description = "List of other AWS accounts which should get write access to the bucket"
  type        = list(string)
  default     = []
}

variable "write_key_pattern" {
  description = "Pattern of object keys allowed for cross-account writes"
  type        = string
  default     = "*"
}

variable "lifecycle_rules" {
  type    = list(any)
  default = []
}

variable "protect" {
  description = "Whether to protect the bucket (and the SNS topic if created) from deletion"
  type        = bool
  default     = false
}
