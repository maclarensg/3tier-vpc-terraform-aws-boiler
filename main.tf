provider "aws" {
  region = "${var.region}"
}

variable "region" {
  description = "The AWS region to deploy to"
  default = "ap-southeast-1"
}