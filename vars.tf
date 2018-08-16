variable "aws_access_key" {
   default = "SUAKEYAQUI"
}
variable "aws_secret_key" {
   default = "SUASECRETAQUI"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "amis" {
  type    = "map"
  default = {
    us-east-1 = "ami-a4c7edb2"
  }
}

variable "key_name" {
  default = "rafakey"
}

variable "instance_type" {
  default = "t2.micro"
}
