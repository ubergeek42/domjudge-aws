variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}
variable "aws_ssh_keyname" {}
variable "aws_availability_zones" {}
variable "sns_topic_arn" {}

# The AMI for your webservers and judgehosts.
# These are probably set in your terraform.tfvars file
variable "web_ami" {}
variable "judge_ami" {}

# The ZoneID and Domain Name in Route53 that you want to use. A subdomain for
# this cluster will be created.
# If you don't want to use this, you need to delete/rename the
# terraform-domserver/route53.tf file so it doesn't end with .tf
variable "route53zone" { default = ""}
variable "route53domain" { default = ""}

# Change this to the id you want to refer to this domjudge cluster by
# E.g. For the USA Southeast Region in 2015, we might use ser2015
variable "djclusterid"          { default="uniqueid" }

########################## DOMServer Settings ##################################
# S3 Bucket for domserver archives. Should match prepare.sh
variable "s3bucket"             { default="domserver-archives"}

# Which archive in your S3 bucket do you want to deploy on your webservers?
# This is the archive you built using prepare.sh
variable "s3archive"            { default="domserver-YYY-MM-DD-HHMMSS.tar.gz"}

# What Instance Type do you want to use for Web Servers?
variable "web_instance_type"    { default="t2.micro" }


########################## Database Settings ##################################
# What Instance Type do you want to use for your mysql database server
variable "rds_instance_type"    { default="t2.micro" }

# Do you want your RDS Instance to run in multiple availability zones?
# This gives you the ability to take snapshots without any downtime, and helps
# protect you against failure of a single availability zone
variable "rds_multiaz"          { default=false }

# This is your database root password. The default firewall rules restrict
# access to it so only the webservers can talk to it, but you may still wish
# to know the password. Choose something random here.
# ASCII only, no /, ", or @ symbols. 8-41 characters.
variable "rds_root_pw"          { default="CHANGE_ME_RANDOM_PASSWORD_GOES_HERE"}


########################## Session Store Settings ##############################
# Provisioned read/write capacity for the dynamodb session table. It should be
# set to something near your expected number of concurrent users.
# Check the pricing page, but it's pretty cheap: https://aws.amazon.com/dynamodb/pricing/
variable "dynamodb_capacity"    { default=10 }


########################## JudgeHost Settings ##################################
# What Instance Type do you want to use for Judge Hosts?
variable "judge_instance_type"  { default="c4.xlarge" }

# What is the base URL for your domjudge server
variable "web_base_address"     { default="http://domjudge.example.com" }

# What is the username/password for the "judgehost" user in your
# domjudge server's web interface.
variable "web_judgehost_user"   { default="judgehost" }
variable "web_judgehost_pass"   { default="judgehost_pass" }

# How many judgehosts do you want?(minimum and maximum)
variable "min_judgehosts"       { default=1 }
variable "max_judgehosts"       { default=4 }

################################################################################
### Don't Touch Below This Line!                                             ###
################################################################################
module "terraform-domserver" {
  s3region = "${var.aws_region}"
  s3bucket = "${var.s3bucket}"
  s3archive = "${var.s3bucket}"

  route53zone = "${var.route53zone}"
  route53domain = "${var.route53domain}"

  web_instance_type = "${var.web_instance_type}"
  web_ami = "${var.web_ami}"

  rds_instance_type = "${var.rds_instance_type}"
  dbmultiaz = "${var.rds_multiaz}"

  dynamo_write_capacity = "${var.dynamodb_capacity}"
  dynamo_read_capacity  = "${var.dynamodb_capacity}"

  dbpass = "${var.rds_root_pw}"

  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
  availability_zones = "${var.aws_availability_zones}"
  ssh_key_name = "${var.aws_ssh_keyname}"
  djclusterid = "${var.djclusterid}"
  notify_arn = "${var.sns_topic_arn}"
  source = "./terraform-domserver"
}


module "terraform-judgehosts" {
  # What is the api endpoint for your DOMjudge contest?
  judgehost_endpoint = "${var.web_base_address}/api/"
  judgehost_username = "${var.web_judgehost_user}"
  judgehost_password = "${var.web_judgehost_pass}"
  judge_instance_type = "${var.judge_instance_type}"
  judgehost_ami = "${var.judge_ami}"

  # How many judges do you want to have(min and max)
  num_judges = "${var.min_judgehosts}"
  max_num_judges = "${var.max_judgehosts}"

  # Don't touch these
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
  availability_zones = "${var.aws_availability_zones}"
  ssh_key_name = "${var.aws_ssh_keyname}"
  djclusterid = "${var.djclusterid}"
  notify_arn = "${var.sns_topic_arn}"
  source = "./terraform-judgehosts"
}
