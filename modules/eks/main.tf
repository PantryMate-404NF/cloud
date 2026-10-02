resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-control-plane-logs"
  })
}

# Kubernetes Secret을 etcd에 저장할 때 봉투 암호화(envelope encryption)에 쓰는 키
resource "aws_kms_key" "secrets" {
  description             = "${var.cluster_name} Kubernetes secrets encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-secrets"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# EKS 컨트롤 플레인 역할이 위 키로 Secret을 암호화·복호화할 수 있도록 허용
data "aws_iam_policy_document" "cluster_secrets_kms" {
  statement {
    sid = "SecretsEncryption"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ListGrants",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.secrets.arn]
  }
}

resource "aws_iam_role_policy" "cluster_secrets_kms" {
  name   = "${var.cluster_name}-secrets-kms"
  role   = element(split("/", var.cluster_role_arn), length(split("/", var.cluster_role_arn)) - 1)
  policy = data.aws_iam_policy_document.cluster_secrets_kms.json
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

  # 한 번 켜면 끌 수 없다. 기존 Secret은 적용 후 재저장해야 새 키로 암호화된다.
  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.secrets.arn
    }
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy.cluster_secrets_kms,
  ]
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

resource "aws_vpc_security_group_ingress_rule" "tailscale_direct" {
  for_each = var.tailscale_direct_enabled ? toset(var.tailscale_direct_source_cidrs) : toset([])

  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description       = "allow tailscale direct udp traffic"

  cidr_ipv4   = each.value
  from_port   = 41641
  to_port     = 41641
  ip_protocol = "udp"
}