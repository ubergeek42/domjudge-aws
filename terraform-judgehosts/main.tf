variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-1"
}
variable "ssh_key_name" {}
variable "availability_zones" {
  default = "us-east-1a,us-east-1b,us-east-1d,us-east-1e"
}
variable "notify_arn" {}

variable "judge_instance_type" {
  default = "t2.micro"
}
variable "judgehost_ami" {}
variable "judgehost_endpoint" {}
variable "judgehost_username" {
  default = "judgehost"
}
variable "judge_spot_price" {
  default = 0
}
variable "judgehost_password" {}
variable "djclusterid" {}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

variable "num_judges" {
  default = 1
}
variable "max_num_judges" {
  default = 4
}

resource "aws_launch_configuration" "judgehosts" {
  image_id = "${var.judgehost_ami}"
  instance_type = "${var.judge_instance_type}"
  key_name = "${var.ssh_key_name}"
  security_groups = [ "${aws_security_group.sg_judgehost.id}" ]
  user_data = <<TEOF
#!/bin/bash
cat >/etc/domjudge/restapi.secret <<EOF
default ${var.judgehost_endpoint}  ${var.judgehost_username}  ${var.judgehost_password}
EOF

chmod 0640 /etc/domjudge/restapi.secret
chown root:domjudge /etc/domjudge/restapi.secret

service judgedaemons stop
service judgedaemons start
TEOF
  enable_monitoring = false
  #spot_price = "${var.judge_spot_price}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "judgehost_asg" {
  name = "${var.djclusterid}-judge-asg"
  launch_configuration = "${aws_launch_configuration.judgehosts.name}"

  availability_zones = ["${split(",", var.availability_zones)}"]
  # or specify vpc_zone_identifier with list of subnets

  desired_capacity = "${var.num_judges}"
  min_size = "${var.num_judges}"
  max_size = "${var.max_num_judges}"

  health_check_grace_period = 300 # wait 5 minutes for instance to boot
  health_check_type = "EC2"

  tag {
    key = "djclusterid"
    value = "${var.djclusterid}"
    propagate_at_launch = true
  }
  tag {
    key = "Name"
    value = "${var.djclusterid} judge"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_policy" "judgehost_asg_policy_out" {
  name = "${var.djclusterid}-judge-asg-scaleout"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300 # 5 minutes
  autoscaling_group_name = "${aws_autoscaling_group.judgehost_asg.name}"
}
resource "aws_autoscaling_policy" "judgehost_asg_policy_in" {
  name = "${var.djclusterid}-judge-asg-scalein"
  scaling_adjustment = "-1"
  adjustment_type = "ChangeInCapacity"
  cooldown = 300 # 5 minutes
  autoscaling_group_name = "${aws_autoscaling_group.judgehost_asg.name}"
}

# Cloudwatch autoscaling triggers
# 40 things to be judged for more than 10 minutes
resource "aws_cloudwatch_metric_alarm" "judge_asg_scaleout" {
    alarm_name = "${var.djclusterid}-judge-asg-scaleout"
    alarm_description = "${var.djclusterid} Scale out judge tier"
    namespace = "DOMjudge"
    metric_name = "${var.djclusterid}-queuesize"
    statistic = "Average"
    evaluation_periods = 2
    period = 300
    threshold = 40 # items in queue
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${aws_autoscaling_policy.judgehost_asg_policy_out.arn}"]
    insufficient_data_actions = []
}
# 20 minutes 5-min judge queue avg less than 20
resource "aws_cloudwatch_metric_alarm" "judge_asg_scalein" {
    alarm_name = "${var.djclusterid}-judge-asg-scalein"
    alarm_description = "${var.djclusterid} Scale in judge tier"
    namespace = "DOMjudge"
    metric_name = "${var.djclusterid}-queuesize"
    statistic = "Average"
    evaluation_periods = 4
    period = 300
    threshold = 20 # less than 20 items in the judging queue
    comparison_operator = "LessThanThreshold"
    alarm_actions = ["${aws_autoscaling_policy.judgehost_asg_policy_in.arn}"]
    insufficient_data_actions = []
}
