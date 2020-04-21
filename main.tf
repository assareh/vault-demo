terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region
}

resource aws_vpc "demo" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc"
  }
}

resource aws_subnet "demo" {
  vpc_id     = aws_vpc.demo.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource aws_security_group "demo" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.demo.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource aws_internet_gateway "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource aws_route_table "demo" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
}

resource aws_route_table_association "demo" {
  subnet_id      = aws_subnet.demo.id
  route_table_id = aws_route_table.demo.id
}

data aws_ami "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-disco-19.04-amd64-server-*"]
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "demo" {
  instance = aws_instance.demo.id
  vpc      = true
}

resource "aws_eip_association" "demo" {
  instance_id   = aws_instance.demo.id
  allocation_id = aws_eip.demo.id
}

resource aws_instance "demo" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.demo.id
  vpc_security_group_ids      = [aws_security_group.demo.id]

  tags = {
    Name = "${var.prefix}-demo-instance"
    ttl         = var.ttl
    owner       = var.owner

  }
}

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.
resource "null_resource" "configure-demo" {
  depends_on = [aws_eip_association.demo]

  provisioner "file" {
    source      = "files/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.demo.private_key_pem
      host        = aws_eip.demo.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/assareh/transit-app-example.git",
      "sudo apt -y update",
      "sudo apt -y install docker.io",
      "sudo docker pull assareh/transit-app-example",
      "sudo docker pull hashicorp/vault-enterprise:1.4.0_ent",
      "sudo docker pull mysql/mysql-server:5.7.21",
      "mkdir ~/mysql-data",
      "sudo docker run --restart=always --name mysql -p 3306:3306 -v ~/mysql-data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_ROOT_HOST=% -e MYSQL_DATABASE=my_app -e MYSQL_USER=vault -e MYSQL_PASSWORD=vaultpw -d mysql/mysql-server:5.7.21",
      "sudo docker run --restart=always --name vault -p 8200:8200 --cap-add=IPC_LOCK -d -e 'VAULT_DEV_ROOT_TOKEN_ID=root' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' hashicorp/vault-enterprise:1.4.0_ent",
      "sudo docker run --restart=always --name transit-app-example -p 5000:5000 -d assareh/transit-app-example",
      "chmod +x *.sh && ./edit_config.sh",
      "./configure_vault.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.demo.private_key_pem
      host        = aws_eip.demo.public_ip
    }
  }
}

resource tls_private_key "demo" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "${var.prefix}-ssh-key.pem"
}

resource aws_key_pair "demo" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.demo.public_key_openssh
}

output "public_dns" {
  value = "http://${aws_eip.demo.public_dns}:5000"
}

output "private_key" {
  value = "${tls_private_key.demo.private_key_pem}"
}
