resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-control-plane-logs"
  })
}

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = var.cluster_role_arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = var.cluster_log_types

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [aws_cloudwatch_log_group.cluster]
}

resource "aws_vpc_security_group_ingress_rule" "node_ssh" {
  count = length(var.ssh_source_security_group_ids)

  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description                  = "Allow SSH to managed nodes from bastion security group ${var.ssh_source_security_group_ids[count.index]}"
  referenced_security_group_id = var.ssh_source_security_group_ids[count.index]
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix            = "${var.cluster_name}-${each.key}-"
  description            = "Ubuntu EKS managed node launch template for ${each.key}"
  image_id               = var.node_ami_id
  key_name               = var.ssh_key_name
  update_default_version = true
  vpc_security_group_ids = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  user_data = base64encode(templatefile(
    each.value.enable_nvidia ? "${path.module}/templates/ubuntu-eks-gpu-user-data.sh.tftpl" : "${path.module}/templates/ubuntu-eks-user-data.sh.tftpl",
    { cluster_name = aws_eks_cluster.this.name }
  ))

  block_device_mappings {
    device_name = var.node_ami_root_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name     = "${var.cluster_name}-${each.key}"
      NodeRole = each.key
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.common_tags, {
      Name     = "${var.cluster_name}-${each.key}"
      NodeRole = each.key
    })
  }

  tags = merge(var.common_tags, {
    Name     = "${var.cluster_name}-${each.key}-launch-template"
    NodeRole = each.key
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = each.value.subnet_ids != null ? each.value.subnet_ids : var.private_subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  labels          = merge({ role = each.key }, each.value.labels)

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = tostring(aws_launch_template.node[each.key].latest_version)
  }

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config {
    max_unavailable = 1
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.common_tags, {
    Name     = "${var.cluster_name}-${each.key}"
    NodeRole = each.key
  })
}
