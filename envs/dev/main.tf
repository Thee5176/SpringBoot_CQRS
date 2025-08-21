# CodeSeries : CodePipeline , CodeDeploy 
# Internet Gateway : allow access in VPC level

##----------------------------VPC Level--------------------------
# VPC : define resource group
resource "aws_vpc" "main_vpc" {
  cidr_block           = "172.16.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "web-server"
  }
}

# Internet Gateway : allow access in VPC level
resource "aws_internet_gateway" "main_igw" {
  vpc_id     = aws_vpc.main_vpc.id
  depends_on = [aws_vpc.main_vpc]
  tags = {
    Name = "web-igw"
  }
}

# Route Table : 
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "web-rt"
  }
}
# Route Table Association : connect subnet with route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.server_subnet.id
  route_table_id = aws_route_table.public_route.id
}

# Route : connect internet gateway with route table
resource "aws_route" "public_route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
  route_table_id         = aws_route_table.public_route.id
}

##-----------------------Credential--------------------------------
# SSH Key
data "aws_key_pair" "deployment_key" { # Manually created on aws console
  key_name = "github_workflow_key"
  tags = {
    Name = "web-server"
  }
}

##------------------------EC2 Instance---------------------------
# EC2 Subnet : define IP address range based on VPC
resource "aws_subnet" "server_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "web-server"
  }
}

# EC2
resource "aws_instance" "web_server" {
  ami                         = "ami-000322c84e9ff1be2" #Amazon Linux 2 (ap-ne-1)
  instance_type               = "t2.micro"
  key_name                    = data.aws_key_pair.deployment_key.key_name
  subnet_id                   = aws_subnet.server_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<EOF
    #!/bin/bash
    
    # Install Docker and Docker Compose
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user

    docker info

    sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose version
  EOF

  tags = {
    Name = "web_server"
  }
}

# EC2 Security Group : allow access in instance level
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id
  ingress { #TODO: Write CD workflow in CodeDeploy and delete this
    description = "SSH from github"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 5743 # Frontend Port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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
    Name = "web-server"
  }
}

##------------------------EC2 Instance---------------------------
# DB_parameter
# DB Subnet Group : 2 or more subnets in different AZ
resource "aws_db_subnet_group" "web_db_subnets" {
  name = "web-db-subnet-group"
  subnet_ids = [
    aws_subnet.db_subnet_1.id,
    aws_subnet.db_subnet_2.id
  ]

  tags = {
    Name = "web-db-subnet-group"
  }
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "web-db"
  }
}
resource "aws_subnet" "db_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = "ap-northeast-1d"

  tags = {
    Name = "web-db"
  }
}
resource "aws_db_parameter_group" "web_db_parameter_group" {
  name        = "web-db-parameter-group"
  description = "Parameter group for web database"
  family      = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = {
    Name = "web_db"
  }
}

# Elastic IP : Set static IP address
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
  tags = {
    Name = "web_eip"
  }
}

# RDS
resource "aws_db_instance" "web_db" {
  identifier             = "web-db"
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  engine_version         = "16.6"
  allocated_storage      = 5
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_schema
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.web_db_subnets.name
  parameter_group_name   = aws_db_parameter_group.web_db_parameter_group.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = {
    Name = "web_db"
  }
}

# DB Security Group
resource "aws_security_group" "db_sg" {
  name        = "web-db-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Postgresql connection"
    from_port   = 5432
    to_port     = 5432
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
    Name = "web-server"
  }
}