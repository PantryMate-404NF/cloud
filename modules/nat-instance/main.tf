data "aws_ssm_parameter" "al2023_ami" {
  name = var.ami_ssm_parameter_name
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name_prefix}-nat-"
  description = "Allow private subnet egress through NAT instances"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_subnets" {
  for_each = var.private_subnet_cidrs

  security_group_id = aws_security_group.this.id
  description       = "Forward traffic from private subnet ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Allow forwarded traffic to the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  for_each = var.public_subnet_ids_by_az

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = each.value
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf install -y iptables-services

    printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-nat-instance.conf
    sysctl --system

    PRIMARY_INTERFACE="$(ip route show default | awk '/default/ {print $5; exit}')"
    iptables -t nat -A POSTROUTING -o "$PRIMARY_INTERFACE" -j MASQUERADE
    iptables -P FORWARD ACCEPT
    service iptables save
    systemctl enable --now iptables
  EOT

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
    Role = "nat"
  })
}

resource "aws_eip" "this" {
  for_each = aws_instance.this

  domain   = "vpc"
  instance = each.value.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })
}

resource "aws_route" "private_internet" {
  for_each = var.private_route_table_ids_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.this[each.key].primary_network_interface_id

  depends_on = [aws_eip.this]
}

