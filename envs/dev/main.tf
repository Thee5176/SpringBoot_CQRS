provider "aws" {
  region = "ap-northeast-1" #japan
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "tls_private_key" "ec2_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "terraform-generated-key"
  public_key = tls_private_key.ec2_ssh_key.public_key_openssh
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name

  tags = {
    Name = "web-server"
  }
}