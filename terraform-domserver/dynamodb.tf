variable "dynamo_read_capacity" {
  default = 1
}
variable "dynamo_write_capacity" {
  default = 1
}
resource "aws_dynamodb_table" "session_table" {
  name = "${var.djclusterid}-sessiontable"
  read_capacity   = "${var.dynamo_read_capacity}"
  write_capacity  = "${var.dynamo_write_capacity}"
  hash_key        = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# Cloudwatch alarms for the dynamodb table
resource "aws_cloudwatch_metric_alarm" "dynamodb-write-capacity-alarm" {
    alarm_name = "${var.djclusterid}-dynamodb-write-capacity-alarm"
    alarm_description = "${var.djclusterid} write capacity limit on the session table"
    namespace = "AWS/DynamoDB"
    metric_name = "ConsumedWriteCapacityUnits"
    dimensions {
      TableName = "${aws_dynamodb_table.session_table.name}"
    }
    statistic = "Sum"
    evaluation_periods = 12
    period = 300
    threshold = "${var.dynamo_write_capacity * 240}"   # 80% of capacity
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
resource "aws_cloudwatch_metric_alarm" "dynamodb-read-capacity-alarm" {
    alarm_name = "${var.djclusterid}-dynamodb-read-capacity-alarm"
    alarm_description = "${var.djclusterid} read capacity limit on the session table"
    namespace = "AWS/DynamoDB"
    metric_name = "ConsumedReadCapacityUnits"
    dimensions {
      TableName = "${aws_dynamodb_table.session_table.name}"
    }
    statistic = "Sum"
    evaluation_periods = 12
    period = 300
    threshold = "${var.dynamo_read_capacity * 240}" # 80% of capacity
    threshold = 28000
    comparison_operator = "GreaterThanThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}

resource "aws_cloudwatch_metric_alarm" "dynamodb-throttled-request-alarm" {
    alarm_name = "${var.djclusterid}-dynamodb-throttled-request-alarm"
    alarm_description = "${var.djclusterid} requests are being throttled on the session table"
    namespace = "AWS/DynamoDB"
    metric_name = "ThrottledRequests"
    dimensions {
      TableName = "${aws_dynamodb_table.session_table.name}"
    }
    statistic = "Sum"
    evaluation_periods = 1
    period = 300
    threshold = 1
    comparison_operator = "GreaterThanOrEqualToThreshold"
    alarm_actions = ["${var.notify_arn}"]
    insufficient_data_actions = ["${var.notify_arn}"]
}
