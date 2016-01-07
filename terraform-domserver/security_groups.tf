# Load Balancer is happy to talk to any and everyone, but only on port 80
resource "aws_security_group" "sg_elb" {
  name = "${var.djclusterid}-elb"
  description = "DOMserver ELB Security Group(${var.djclusterid})"
  ingress {
    from_port    = 80
    to_port      = 80
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name        = "${var.djclusterid}-elb"
    djclusterid = "${var.djclusterid}"
  }
}

# Limit web servers so only the load balancer can talk to them directly
# Outbound traffic from them is unrestricted.
resource "aws_security_group" "sg_web" {
  name = "${var.djclusterid}-web"
  description = "DOMserver Webserver Security Group(${var.djclusterid})"
  tags {
    Name        = "${var.djclusterid}-web"
    djclusterid = "${var.djclusterid}"
  }
}
resource "aws_security_group_rule" "sg_web_ingress" {
  type = "ingress"
  from_port    = 80
  to_port      = 80
  protocol     = "tcp"

  security_group_id = "${aws_security_group.sg_web.id}"
  source_security_group_id = "${aws_security_group.sg_elb.id}"
}
resource "aws_security_group_rule" "sg_web_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sg_web.id}"
}


# Limit RDS access to just the web servers
resource "aws_security_group" "sg_rds" {
  name = "${var.djclusterid}-rds"
  description = "DOMserver Database Security Group(${var.djclusterid})"
  tags {
    Name        = "${var.djclusterid}-rds"
    djclusterid = "${var.djclusterid}"
  }
}
resource "aws_security_group_rule" "sg_rds_ingress" {
  type = "ingress"
  from_port    = 3306
  to_port      = 3306
  protocol     = "tcp"

  security_group_id = "${aws_security_group.sg_rds.id}"
  source_security_group_id = "${aws_security_group.sg_web.id}"
}

# If for some reason your RDS needs to be world accessible, uncomment this and
# remove the previous sg_rds_ingress rule
/*
resource "aws_security_group_rule" "sg_rds_ingress_world" {
  type = "ingress"
  from_port    = 3306
  to_port      = 3306
  protocol     = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sg_rds.id}"
}
*/
