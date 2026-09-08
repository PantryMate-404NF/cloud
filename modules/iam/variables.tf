variable "name_prefix" {
  description = "Prefix used for IAM role names."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to IAM roles."
  type        = map(string)
  default     = {}
}

variable "additional_node_policy_arns" {
  description = "Additional managed policies to attach to the node role when capabilities are added later."
  type        = set(string)
  default     = []
}

