variable "project_name" {
  description = "Prefix for AWS resources (must be globally unique for S3 buckets)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}