variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "The name of the project to use for naming resources"
  type        = string
  default     = "lsm-fyp"
}
