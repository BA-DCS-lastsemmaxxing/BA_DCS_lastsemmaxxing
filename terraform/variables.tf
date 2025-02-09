variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

variable "s3_name" {
  description = "The name of the S3 bucket to create"
  type        = string
  default     = "lsm-fyp-s3"
}
