resource "aws_instance" "rafael-devops" {
  ami             = "${lookup(var.amis, var.aws_region)}"
  instance_type   = "${var.instance_type}"
  security_groups = ["sg_DefaultWebserver"]
  key_name        = "${var.key_name}"
  user_data       = "${file("startup.sh")}"

    tags {
    Name            = "rafael-devops"
    Provider        = "terraform"
    Role            = "test"
  }
}
