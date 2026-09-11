controller:
  # Jenkins LTS 최신 이미지
  image:
    tag: "2.504.3-lts-jdk21"

  # ── 서비스: 내부 NLB ──────────────────────────────────────────────────────
  # Lambda webhook relay가 VPC 내부에서 이 NLB를 통해 Jenkins에 접근합니다.
  # VPN/배스천 사용자도 이 NLB 주소로 UI에 접근합니다.
  serviceType: LoadBalancer
  servicePort: 8080
  serviceAnnotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

  # ── 노드 배치: manage 노드에만 스케줄링 ──────────────────────────────────
  nodeSelector:
    role: "${manage_node_label}"

  tolerations: []

  # ── 리소스 ────────────────────────────────────────────────────────────────
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

  # ── IRSA Service Account ──────────────────────────────────────────────────
  serviceAccount:
    create: true
    name: jenkins
    annotations:
      eks.amazonaws.com/role-arn: "${jenkins_role_arn}"

  # ── 영구 볼륨 (EBS gp3) ──────────────────────────────────────────────────
  persistence:
    enabled: true
    size: "20Gi"
    storageClass: "gp2"

  # ── 플러그인 ──────────────────────────────────────────────────────────────
  installPlugins:
    - kubernetes:latest
    - workflow-aggregator:latest
    - git:latest
    - github:latest
    - github-branch-source:latest
    - job-dsl:latest
    - credentials-binding:latest
    - pipeline-stage-view:latest
    - timestamper:latest
    - ws-cleanup:latest
    - plain-credentials:latest

  # ── JCasC (Jenkins Configuration as Code) ────────────────────────────────
  JCasC:
    defaultConfig: true
    configScripts:

      # Jenkins 시스템 및 Kubernetes 클라우드 설정
      jenkins-casc: |
        jenkins:
          systemMessage: "Jenkins CI/CD — ${name_prefix} (managed by Terraform/JCasC)"
          numExecutors: 0
          clouds:
            - kubernetes:
                name: "kubernetes"
                serverUrl: "https://kubernetes.default.svc"
                namespace: "${namespace}"
                jenkinsUrl: "http://jenkins.${namespace}.svc.cluster.local:8080"
                jenkinsTunnel: "jenkins-agent.${namespace}.svc.cluster.local:50000"
                maxRequestsPerHost: 32
                templates:
                  - name: "jenkins-agent"
                    namespace: "${namespace}"
                    label: "jenkins-agent"
                    nodeUsageMode: NORMAL
                    nodeSelector: "role=${worker_node_label}"
                    containers:
                      - name: jnlp
                        image: "jenkins/inbound-agent:latest-jdk21"
                        alwaysPullImage: true
                        resourceRequestCpu: "500m"
                        resourceRequestMemory: "512Mi"
                        resourceLimitCpu: "1"
                        resourceLimitMemory: "1Gi"
                    idleMinutes: 5
                    activeDeadlineSeconds: 1800

      # GitHub 자격증명 및 웹훅 시크릿 설정
      credentials-casc: |
        credentials:
          system:
            domainCredentials:
              - credentials:
                  - usernamePassword:
                      id: "github-credentials"
                      description: "GitHub API Token for Jenkins"
                      username: "${github_org}"
                      password: "${github_api_token}"
                      scope: GLOBAL
                  - string:
                      id: "github-webhook-secret"
                      description: "GitHub Webhook Shared Secret"
                      secret: "${github_webhook_secret}"
                      scope: GLOBAL

      # GitHub 플러그인 서버 설정 (API 레이트리밋 방지)
      github-casc: |
        unclassified:
          gitHubPluginConfig:
            configs:
              - name: "GitHub"
                apiUrl: "https://api.github.com"
                credentialsId: "github-credentials"
                manageHooks: false

      # 파이프라인 잡 자동 생성 (frontend, backend 각각 Multibranch Pipeline)
      jobs-casc: |
        jobs:
          - script: |
              multibranchPipelineJob('${frontend_repo_name}') {
                description('Frontend service — ${github_org}/${frontend_repo_name}')
                branchSources {
                  branchSource {
                    source {
                      github {
                        id('${frontend_repo_name}-source')
                        credentialsId('github-credentials')
                        repoOwner('${github_org}')
                        repository('${frontend_repo_name}')
                        traits {
                          gitHubBranchDiscovery { strategyId(1) }
                          gitHubPullRequestDiscovery { strategyId(1) }
                        }
                      }
                    }
                  }
                }
                factory {
                  workflowBranchProjectFactory {
                    scriptPath('Jenkinsfile')
                  }
                }
                triggers {
                  periodic(1)
                }
                orphanedItemStrategy {
                  discardOldItems {
                    numToKeep(5)
                  }
                }
              }
          - script: |
              multibranchPipelineJob('${backend_repo_name}') {
                description('Backend service — ${github_org}/${backend_repo_name}')
                branchSources {
                  branchSource {
                    source {
                      github {
                        id('${backend_repo_name}-source')
                        credentialsId('github-credentials')
                        repoOwner('${github_org}')
                        repository('${backend_repo_name}')
                        traits {
                          gitHubBranchDiscovery { strategyId(1) }
                          gitHubPullRequestDiscovery { strategyId(1) }
                        }
                      }
                    }
                  }
                }
                factory {
                  workflowBranchProjectFactory {
                    scriptPath('Jenkinsfile')
                  }
                }
                triggers {
                  periodic(1)
                }
                orphanedItemStrategy {
                  discardOldItems {
                    numToKeep(5)
                  }
                }
              }

# ── 빌드 에이전트: worker 노드에 스케줄링 ────────────────────────────────────
agent:
  enabled: true
  namespace: "${namespace}"
  nodeSelector:
    role: "${worker_node_label}"
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1Gi"

# ── RBAC ─────────────────────────────────────────────────────────────────────
rbac:
  create: true
  readSecrets: true
