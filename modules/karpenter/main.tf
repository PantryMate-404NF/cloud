module "karpenter_aws" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.24.1"

  cluster_name = var.cluster_name

  namespace       = var.namespace
  service_account = "karpenter"

  create_pod_identity_association = true

  # Karpenter Controller 권한을 IAM Managed Policy가 아닌
  # Role Inline Policy로 생성하여 6,144자 Managed Policy 제한 회피
  enable_inline_policy = true

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"

  create_access_entry = true

  enable_spot_termination = true

  tags = var.tags
}

resource "helm_release" "karpenter" {
  name      = "karpenter"
  namespace = var.namespace

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  wait    = true
  atomic  = true
  timeout = 900

  values = [
    yamlencode({
      replicas = 1

      nodeSelector = {
        role = "manage"
      }

      settings = {
        clusterName       = var.cluster_name
        interruptionQueue = module.karpenter_aws.queue_name
      }

      controller = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }

          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
    })
  ]

  depends_on = [
    module.karpenter_aws
  ]
}