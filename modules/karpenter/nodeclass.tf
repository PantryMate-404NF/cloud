resource "kubectl_manifest" "ec2_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"

    metadata = {
      name = "default"
    }

    spec = {
      role = module.karpenter_aws.node_iam_role_name

      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]

      subnetSelectorTerms = [
        for subnet_id in var.private_subnet_ids : {
          id = subnet_id
        }
      ]

      securityGroupSelectorTerms = [
        {
          id = var.cluster_security_group_id
        }
      ]

      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"

          ebs = {
            volumeType          = "gp3"
            volumeSize          = "20Gi"
            encrypted           = true
            deleteOnTermination = true
          }
        }
      ]

      tags = merge(
        var.tags,
        {
          "Name" = "${var.cluster_name}-karpenter"
        }
      )
    }
  })

  depends_on = [
    helm_release.karpenter
  ]
}