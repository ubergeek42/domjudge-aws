resource "aws_security_group" "sg_judgehost" {
  name = "${var.djclusterid}-judgehost"
  description = "DOMserver Judgehost Security Group(${var.djclusterid})"
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name        = "${var.djclusterid}-judgehost"
    djclusterid = "${var.djclusterid}"
  }
}
