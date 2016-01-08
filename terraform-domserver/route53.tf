variable "use_route53" {}
variable "route53zone" {}
variable "route53domain" {}

resource "aws_route53_record" "www" {
  count = "${var.use_route53}"
  zone_id = "${var.route53zone}"
  name = "${var.djclusterid}.${var.route53domain}"
  type = "A"

  alias {
    name = "${aws_elb.web_elb.dns_name}"
    zone_id = "${aws_elb.web_elb.zone_id}"
    evaluate_target_health = false
  }
}

output "web_dns_record" {
  value = "http://${aws_route53_record.www.name}"
}
