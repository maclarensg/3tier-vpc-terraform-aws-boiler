provider "aws" {
  region     = "ap-southeast-1"
}

resource "aws_instance" "example" {
  ami           = "ami-08cf069e7776615af"
  instance_type = "t2.micro"
}
