resource "aws_iam_instance_profile" "webserver_iam_profile" {
  name = "${var.djclusterid}-iam-web-profile"
  roles = ["${aws_iam_role.webserver_iam_role.name}"]
  path = "/domjudge/"
}

resource "aws_iam_role" "webserver_iam_role" {
  name = "${var.djclusterid}-iam-web-role"
  path = "/domjudge/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy" "webserver_iam_policy" {
  name = "DynamoDB-cloudwatch"
  role = "${aws_iam_role.webserver_iam_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "stmt1",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "${aws_dynamodb_table.session_table.arn}"
    },
    {
      "Sid": "stmt2",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "stmt3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3bucket}",
        "arn:aws:s3:::${var.s3bucket}/*"
      ]
    }
  ]
}
EOF
}
