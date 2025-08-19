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

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "ssh_deploy_key"
  public_key = file("~/.ssh/my_ec2_key.pub")
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = resource.aws_key_pair.ec2_key_pair.key_name

  tags = {
    Name = "web-server"
  }
}