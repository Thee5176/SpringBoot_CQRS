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

data "aws_key_pair" "deployment_key" {
  key_name = "github_workflow_key" # Manually created on aws console
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = data.aws_key_pair.deployment_key.key_name

  tags = {
    Name = "web-server"
  }
}