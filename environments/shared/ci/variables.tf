variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "github_repository" {
  type    = string
  default = "PantryMate-404NF/cloud"
}

variable "terraform_state_bucket" {
  type    = string
  default = "pantry-mate-tstate-542119828072-apne2"
}
