variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

# variable "aws_access_key" {
#   description = "The AWS access key"
#   type        = string
# }

# variable "aws_secret_key" {
#   description = "The AWS secret key"
#   type        = string
# }

variable "s3_name" {
  description = "The name of the S3 bucket to create"
  type        = string
  default     = "lsm-fyp-s3"
}
