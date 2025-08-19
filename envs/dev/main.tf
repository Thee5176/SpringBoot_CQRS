provider "aws" {
  region = "ap-northeast-1" #japan
}

resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows SSH from any IP address
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

data "aws_key_pair" "deployment_key" {
  key_name = "github_workflow_key" # Manually created on aws console
}

resource "aws_instance" "web_server" {
  ami                    = "ami-07faa35bbd2230d90" #Amazon linux AMI
  instance_type          = "t2.micro"
  key_name               = data.aws_key_pair.deployment_key.key_name
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = "web-server"
  }
}