variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-1"
}
variable "djclusterid" {}

variable "s3region" {
  default = "us-east-1"
}
variable "s3bucket" {}
variable "s3archive" {}

variable "availability_zones" {
  default = "us-east-1a,us-east-1b,us-east-1d,us-east-1e"
}

variable "notify_arn" {}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

output "djclusterid" {
  value = "${var.djclusterid}"
}

output "web_elb_endpoint" {
  value = "${aws_elb.web_elb.dns_name}"
}
