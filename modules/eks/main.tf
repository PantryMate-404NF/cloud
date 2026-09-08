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

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  ami_type        = each.value.ami_type
  disk_size       = each.value.disk_size
  labels          = merge({ role = each.key }, each.value.labels)

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

