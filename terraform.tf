terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-south-1"
}

resource "aws_vpc" "tf-proj-vpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_internet_gateway" "tf-proj-gw" {
  vpc_id = aws_vpc.tf-proj-vpc.id

  tags = {
    Name = "tf-gateway"
  }
}

resource "aws_route_table" "tf-route-table" {
  vpc_id = aws_vpc.tf-proj-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-proj-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.tf-proj-gw.id
  }

  tags = {
    Name = "tf-rt"
  }
}

resource "aws_subnet" "tf-sn" {
  vpc_id     = aws_vpc.tf-proj-vpc.id
  cidr_block = "172.31.0.0/16"

  tags = {
    Name = "tf-subnet"
  }
}

resource "aws_route_table_association" "tf-rt" {
  subnet_id      = aws_subnet.tf-sn.id
  route_table_id = aws_route_table.tf-route-table.id
}

resource "aws_security_group" "tf-sg" {
  name = "tf-sg"
  description = "Allow HTTP and SSH traffic via Terraform"
  vpc_id     = aws_vpc.tf-proj-vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
   description = "HTTP traffic"
   from_port = 0
   to_port = 65000
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }

 ingress {
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
}

resource "aws_network_interface" "tf-ni" {
  subnet_id       = aws_subnet.tf-sn.id
  private_ips     = ["172.31.1.14"]
  security_groups = [aws_security_group.tf-sg.id]
}

resource "aws_eip" "tf-eip" {
  vpc                    = true
  network_interface         = aws_network_interface.tf-ni.id
  associate_with_private_ip = "172.31.1.14"
}

resource "aws_instance" "Production-Server" {
  ami           = "ami-0287a05f0ef0e9d9a"
  instance_type = "t2.micro"
  key_name = "awskeypair"
  network_interface {
  device_index = 0
  network_interface_id         = aws_network_interface.tf-ni.id
  }
  user_data  = <<-EOF
 #!/bin/bash
     sudo apt-get update -y
     sudo apt install docker.io -y
     sudo systemctl enable docker
     sudo docker run -itd -p 8085:8081 dhrutidocker/insuranceproject:1.0
     sudo docker start $(docker ps -aq)
 EOF
 tags = {
 Name = "Production-Server"
 }
}
