terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region
}

resource aws_vpc "hashicat" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc"
  }
}

resource aws_subnet "hashicat" {
  vpc_id     = aws_vpc.hashicat.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource aws_security_group "hashicat" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.hashicat.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource aws_internet_gateway "hashicat" {
  vpc_id = aws_vpc.hashicat.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource aws_route_table "hashicat" {
  vpc_id = aws_vpc.hashicat.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashicat.id
  }
}

resource aws_route_table_association "hashicat" {
  subnet_id      = aws_subnet.hashicat.id
  route_table_id = aws_route_table.hashicat.id
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

resource "aws_eip" "hashicat" {
  instance = aws_instance.hashicat.id
  vpc      = true
}

resource "aws_eip_association" "hashicat" {
  instance_id   = aws_instance.hashicat.id
  allocation_id = aws_eip.hashicat.id
}

resource aws_instance "hashicat" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashicat.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.hashicat.id
  vpc_security_group_ids      = [aws_security_group.hashicat.id]

  tags = {
    Name = "${var.prefix}-hashicat-instance"
    ttl         = var.ttl
    owner       = var.owner

  }
}

# We're using a little trick here so we can run the provisioner without
# destroying the VM. Do not do this in production.

# If you need ongoing management (Day N) of your virtual machines a tool such
# as Chef or Puppet is a better choice. These tools track the state of
# individual files and can keep them in the correct configuration.

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.
resource "null_resource" "configure-cat-app" {
  depends_on = [aws_eip_association.hashicat]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "files/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.hashicat.private_key_pem
      host        = aws_eip.hashicat.public_ip
    }
  }
# i can move some of this to a standalone script copied over using file provisioner
  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sudo apt -y install docker.io unzip python3-pip",
      "sudo docker pull mysql/mysql-server:5.7.21",
      "mkdir ~/mysql-data",
      "sudo docker run --name mysql -p 3306:3306 -v ~/mysql-data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_ROOT_HOST=% -e MYSQL_DATABASE=my_app -e MYSQL_USER=vault -e MYSQL_PASSWORD=vaultpw -d mysql/mysql-server:5.7.21",
      "git clone https://github.com/assareh/transit-app-example.git",
      "curl -O https://releases.hashicorp.com/vault/1.4.0+ent/vault_1.4.0+ent_linux_amd64.zip && unzip vault_1.4.0+ent_linux_amd64.zip",
      "sudo mv vault /usr/local/bin/",
      "vault server -dev -dev-root-token-id=root &",
      "export VAULT_ADDR=http://localhost:8200",
      "export VAULT_TOKEN=root",
      "vault audit enable file file_path=/tmp/vault_audit.log",
      "vault secrets enable -path=lob_a/workshop/database database",
      "pip3 install Flask mysql-connector-python hvac",
      "cd ~/transit-app-example/backend && python3 app.py &",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.hashicat.private_key_pem
      host        = aws_eip.hashicat.public_ip
    }
  }
}

resource tls_private_key "hashicat" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "${var.prefix}-ssh-key.pem"
}

resource aws_key_pair "hashicat" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.hashicat.public_key_openssh
}

output "public_dns" {
  value = "http://${aws_eip.hashicat.public_dns}"
}

# how to save this to a file
output "private_key" {
  value = "${tls_private_key.hashicat.private_key_pem}"
}