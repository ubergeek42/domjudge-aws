variable "web_instance_type" {
  default = "t2.micro"
}
variable "web_ami" {}
variable "ssh_key_name" {}
variable "web_spot_price" {
  default = 0
}

resource "aws_elb" "web_elb" {
  name = "${var.djclusterid}-elb"
  availability_zones = ["${split(",", var.availability_zones)}"]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  connection_draining = true
  connection_draining_timeout = 30
  cross_zone_load_balancing = true
  security_groups = [ "${aws_security_group.sg_elb.id}" ]
  health_check {
    target = "HTTP:80/public/index.php"
    interval = 15
    timeout = 10
    unhealthy_threshold = 10 # 2.5 minutess of failure
    healthy_threshold = 2 # 30 seconds of success
  }
  tags {
    Name        = "${var.djclusterid}-elb"
    djclusterid = "${var.djclusterid}"
  }
}

resource "aws_launch_configuration" "webserver_conf" {
  image_id = "${var.web_ami}"
  instance_type = "${var.web_instance_type}"
  key_name = "${var.ssh_key_name}"
  security_groups = [ "${aws_security_group.sg_web.id}" ]
  user_data = <<EOF
#!/bin/bash
# The archive that contains the version of domserver to install
cat >/root/env_vars <<EVARS
export DOMSERVER_S3_BUCKET="${var.s3bucket}"
export DOMSERVER_S3_FILE="${var.s3archive}"
export DOMSERVER_S3_REGION="${var.s3region}"

# Set variables that the install script might need
export DJCLUSTERID="${var.djclusterid}"
export DYNAMODB_REGION="${var.region}"
export DYNAMODB_TABLE="${aws_dynamodb_table.session_table.name}"
export DBHOST="${aws_db_instance.rds_instance.address}"
export DBNAME="${var.dbname}"
export DBUSER="${var.dbuser}"
export DBPASS="${var.dbpass}"
EVARS
source /root/env_vars
/root/deploy_domserver.sh
exit 0
EOF
  enable_monitoring = true
  iam_instance_profile = "${aws_iam_instance_profile.webserver_iam_profile.name}"

  #spot_price = "${var.web_spot_price}"

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_policy" "webserver_asg_policy_out" {
  name = "${var.djclusterid}-web-asg-scaleout"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300 # 5 minutes
  autoscaling_group_name = "${aws_autoscaling_group.webserver_asg.name}"
}
resource "aws_autoscaling_policy" "webserver_asg_policy_in" {
  name = "${var.djclusterid}-web-asg-scalein"
  scaling_adjustment = "-1"
  adjustment_type = "ChangeInCapacity"
  cooldown = 300 # 5 minutes
  autoscaling_group_name = "${aws_autoscaling_group.webserver_asg.name}"
}
resource "aws_autoscaling_group" "webserver_asg" {
  name = "${var.djclusterid}-web-asg"
  launch_configuration = "${aws_launch_configuration.webserver_conf.name}"
  load_balancers = ["${aws_elb.web_elb.name}"]

  availability_zones = ["${split(",", var.availability_zones)}"]
  # or specify vpc_zone_identifier with list of subnets

  desired_capacity = 1
  min_size = 1
  max_size = 4

  health_check_grace_period = 360 # wait 5 minutes for elb checks to come up
  health_check_type = "ELB"
  #health_check_type = "EC2"

  tag {
    key = "djclusterid"
    value = "${var.djclusterid}"
    propagate_at_launch = true
  }
  tag {
    key = "Name"
    value = "${var.djclusterid} web"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Cloudwatch autoscaling triggers
# 5 minutes of cpu average over 80%, add an instance
resource "aws_cloudwatch_metric_alarm" "web_asg_scaleout" {
    alarm_name = "${var.djclusterid}-web-asg-scaleout"
    alarm_description = "${var.djclusterid} Scale out web tier"
    namespace = "AWS/EC2"
    metric_name = "CPUUtilization"
    dimensions {
      AutoScalingGroupName = "${aws_autoscaling_group.webserver_asg.name}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 80 # 80% cpu average across all hosts
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${aws_autoscaling_policy.webserver_asg_policy_out.arn}"]
    insufficient_data_actions = []
}
# 20 minutes 5-min cpu usage less than 30%, remove an instance
resource "aws_cloudwatch_metric_alarm" "web_asg_scalein" {
    alarm_name = "${var.djclusterid}-web-asg-scalein"
    alarm_description = "${var.djclusterid} Scale in web tier"
    namespace = "AWS/EC2"
    metric_name = "CPUUtilization"
    dimensions {
      AutoScalingGroupName = "${aws_autoscaling_group.webserver_asg.name}"
    }
    statistic = "Average"
    evaluation_periods = 4
    period = 300
    threshold = 30 # less than 30% cpu across hosts
    comparison_operator = "LessThanThreshold"
    alarm_actions = ["${aws_autoscaling_policy.webserver_asg_policy_in.arn}"]
    insufficient_data_actions = []
}


# Cloudwatch Alarms
resource "aws_cloudwatch_metric_alarm" "elb-healthyhost-count-alarm" {
    alarm_name = "${var.djclusterid}-elb-healthyhost-count-alarm"
    alarm_description = "${var.djclusterid} ELB no healthy backend hosts"
    namespace = "AWS/ELB"
    metric_name = "HealthyHostCount"
    dimensions {
      LoadBalancerName = "${aws_elb.web_elb.name}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 1 # minimum 1 healthy host
    comparison_operator = "LessThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "elb-latency-alarm" {
    alarm_name = "${var.djclusterid}-elb-latency-alarm"
    alarm_description = "${var.djclusterid} HIGH ELB latency"
    namespace = "AWS/ELB"
    metric_name = "Latency"
    dimensions {
      LoadBalancerName = "${aws_elb.web_elb.name}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 0.5 # 0.5s latency
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "elb-5xx-backend-alarm" {
    alarm_name = "${var.djclusterid}-elb-5xx-backend-alarm"
    alarm_description = "${var.djclusterid} HIGH ELB backend 5xx error rate"
    namespace = "AWS/ELB"
    metric_name = "HTTPCode_Backend_5XX"
    dimensions {
      LoadBalancerName = "${aws_elb.web_elb.name}"
    }
    statistic = "Sum"
    evaluation_periods = 1
    period = 300
    threshold = 0
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
