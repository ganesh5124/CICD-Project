# VPC creation of AWS
resource "aws_vpc" "dev-vpc" {
  cidr_block = "172.82.0.0/16"
  tags = {
    Name = "dev-vpc"
  }
  enable_dns_hostnames = true
}

# Internet Gateway
resource "aws_internet_gateway" "dev-igw" {
  vpc_id     = aws_vpc.dev-vpc.id
  depends_on = [aws_vpc.dev-vpc]
  tags = {
    Name = "dev-igw"
  }
}

# Route table
resource "aws_route_table" "dev-rt" {
  vpc_id     = aws_vpc.dev-vpc.id
  depends_on = [aws_internet_gateway.dev-igw, aws_vpc.dev-vpc, ]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-igw.id
  }
  tags = {
    Name = "dev-rt"
  }
}

# Subnet creation
resource "aws_subnet" "dev-subnet" {
  depends_on              = [aws_vpc.dev-vpc, aws_route_table.dev-rt]
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = "172.82.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "dev-subnet"
  }
}

# Route table association
resource "aws_route_table_association" "dev-rt-association" {
  subnet_id      = aws_subnet.dev-subnet.id
  route_table_id = aws_route_table.dev-rt.id
  depends_on     = [aws_subnet.dev-subnet, aws_route_table.dev-rt]
}

# Security Group
resource "aws_security_group" "dev-jenkins-sg" {
  name        = "jenkins-sg"
  vpc_id      = aws_vpc.dev-vpc.id
  depends_on  = [aws_vpc.dev-vpc, aws_subnet.dev-subnet]
  description = "HTTP, PING, SSH"
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Ping"
    from_port   = 0
    to_port     = 0
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "output"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-sg"
  }
}

# Security Group
# resource "aws_security_group" "dev-myapp-sg" {
#   name       = "MYAPP-sg"
#   vpc_id     = aws_vpc.dev-vpc.id
#   depends_on = [aws_vpc.dev-vpc, aws_subnet.dev-subnet]

#   ingress {
#     description = "ACCESS"
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     description = "SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     description = "output"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "demo-sg"
#   }
# }

# Key Pair
resource "aws_key_pair" "dev-key_pair" {
  key_name   = "dev-key_pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDeCCSYVlNfrWJY8D4dQ64Y+xkdACqY0KYhR0pQyqEkvCLJahJEaY+ANTKqsBII9RK3PRf12eqh2w0VaPbA0cQYBvzO6q/YLWRbmtqW9Sk6s2XozaAAFFOIuFrqFVvTHALOKh8RnDmqdq1PdpWRQNdq2YSDjjph98mmT8pgWxLyPAnn0xQfciRRiAvoKjJvTp+a/G5nUhik7PUdA2mgJU7oUcDHmxpBV3i+8gyHoWw49M7dxJKW3QgaudcEmWwjcUA+wlhRMp1InbiUl+Npcj9ETa3WhZqebV/1g6n3yMMoj79BL2ZuW4ujz+bZnoJXLk76vI89kYqkGs5VcU2NY0P4oOKgQ4dAy6J8bqnmioOso+jyYAEfvxkrJSQS+HiLeZg8ACRN+TPL0nZSrlLxJubf3POXV0l3RRaJ8+vptSIMiTtGmcRqiiz5s2e19VOpSLr+bnVsQldmon/uSYheeK1hsAwQkWL4GGnfuAKSHGliua2Rz13cAGnWym1fQedRDPs= pepakayalaveeraganeshkumar@Ganesh"
  tags = {
    Name = "dev-key_pair"
  }
}

# Instance for Jenkins
resource "aws_instance" "dev-jenkins-ec2-instance" {
  vpc_security_group_ids = [aws_security_group.dev-jenkins-sg.id]
  subnet_id              = aws_subnet.dev-subnet.id
  key_name               = aws_key_pair.dev-key_pair.id
  ami                    = "ami-068e0f1a600cd311c"
  instance_type          = "t2.xlarge"
  tags = {
    Name = "dev-jenkins-ec2-instance"
  }
  connection {
    user        = "ec2-user"
    type        = "ssh"
    host        = self.public_ip
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update –y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
      "sudo yum upgrade",
      "sudo dnf install java-17-amazon-corretto -y",
      "sudo yum install jenkins -y",
      "sudo systemctl enable jenkins",
      "sudo systemctl start jenkins",
      "sudo yum install tree -y",
      "sudo yum install maven git -y",
      "sudo yum install ansible -y",
      "sudo yum install docker -y",
      "sudo chmod 666 /var/run/docker.sock",
      "sudo systemctl start docker",
      "sudo usermod -aG docker jenkns",
      "sudo usermod -aG docker $USER",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "sudo docker run -itd --name sonar -p 9000:9000 sonarqube",
      "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm",
    ]
  }
}

# Instance for Jenkins
# resource "aws_instance" "dev-myapp-ec2-instance" {
#   vpc_security_group_ids = [aws_security_group.dev-myapp-sg.id]
#   subnet_id              = aws_subnet.dev-subnet.id
#   key_name               = aws_key_pair.dev-key_pair.id
#   ami                    = "ami-0e1d06225679bc1c5"
#   instance_type          = "t2.micro"
#   tags = {
#     Name = "dev-myapp-ec2-instance"
#   }
# }
