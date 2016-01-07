variable dbname {
  default = "domjudge"
}
variable dbuser {
  default = "domjudge"
}
variable dbpass {}
variable "rds_instance_type" {
  default = "db.t2.micro"
}
variable dbmultiaz {
  default = false
}

resource "aws_db_parameter_group" "default" {
  name          = "${var.djclusterid}-rds-parameters"
  family        = "mysql5.6"
  description   = "${var.djclusterid} database configuration"

  parameter {
    name  = "max_allowed_packet"
    value = "268435456"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier = "${var.djclusterid}-rds"
  allocated_storage   = 10
  storage_type        = "gp2"
  instance_class      = "${var.rds_instance_type}"
  multi_az            = "${var.dbmultiaz}"
  apply_immediately = true

  name="${var.dbname}"
  username="${var.dbuser}"
  password="${var.dbpass}"

  publicly_accessible = true

  parameter_group_name = "${var.djclusterid}-rds-parameters"
  vpc_security_group_ids = ["${aws_security_group.sg_rds.id}"]
  engine  = "mysql"
  engine_version = "5.6.23" # TODO: shouldn't be required(see https://github.com/hashicorp/terraform/issues/3465)
  maintenance_window = "tue:00:00-tue:01:00"
  backup_window = "01:00-02:00"

  # TODO: ability to add tags?
}

resource "aws_cloudwatch_metric_alarm" "rds-cpu-alarm" {
    alarm_name = "${var.djclusterid}-rds-cpu-alarm"
    alarm_description = "${var.djclusterid} HIGH RDS CPU utilization"
    namespace = "AWS/RDS"
    metric_name = "CPUUtilization"
    dimensions {
      DBInstanceIdentifier = "${aws_db_instance.rds_instance.identifier}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 50 # higher than 50% cpu
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "rds-free-space" {
    alarm_name = "${var.djclusterid}-rds-free-space"
    alarm_description = "${var.djclusterid} LOW free storage space"
    namespace = "AWS/RDS"
    metric_name = "FreeStorageSpace"
    dimensions {
      DBInstanceIdentifier = "${aws_db_instance.rds_instance.identifier}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 1000000000 # less than 1G of space left
    comparison_operator = "LessThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "rds-read-latency" {
    alarm_name = "${var.djclusterid}-rds-read-latency"
    alarm_description = "${var.djclusterid} HIGH read latency"
    namespace = "AWS/RDS"
    metric_name = "ReadLatency"
    dimensions {
      DBInstanceIdentifier = "${aws_db_instance.rds_instance.identifier}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 0.1 # 100ms
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "rds-write-latency" {
    alarm_name = "${var.djclusterid}-rds-write-latency"
    alarm_description = "${var.djclusterid} HIGH write latency"
    namespace = "AWS/RDS"
    metric_name = "WriteLatency"
    dimensions {
      DBInstanceIdentifier = "${aws_db_instance.rds_instance.identifier}"
    }
    statistic = "Average"
    evaluation_periods = 1
    period = 300
    threshold = 0.1 # 100ms
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
