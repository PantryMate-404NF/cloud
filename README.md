# Pantry-Mate
Pantry-Mate는 클라우드와 온프레미스를 같이 운용하는 하이브리드 환경을 구성했습니다.

AWS 환경은 Amazon EKS와 Terraform을 기반으로 구성했으며, 애플리케이션 배포 자동화, 인프라 코드 검증, 모니터링 환경 및 온프레미스 DB 연동을 구축했습니다.

개발 환경에서는 비용을 최소화하면서 필요한 리소스를 선택적으로 실행할 수 있도록 인프라의 생명 주기와 운영 방식을 분리하여 구성했습니다.

---
## 아키텍처
```bash
Github
└ Terraform / app code
               │
 GitHub Actions│
               ↓
              AWS
         ├─ Amazon EKS
         ├─ Amazon ECR
         ├─ Amazon S3
         └─ Amazon RDS
               │  
         │ tailscale │
               ↓            
        ├─ Kubernetes Cluster
        ├─ PostgreSQL
        │  ├─ Primary
        │  └─ Replica
        └─ Monitoring
```
AWS EKS와 온프레미스 VM 환경은 tailscale 기반 사설 네트워크로 연결했습니다.

---
## 기술 스택

| Category | Technology |
| --- | --- |
| Cloud | AWS |
| Container / Orchestration | Amazon EKS / Kubernetes |
| IaC | Terraform |
| Container Registry | Amazon ECR |
| CI | GitHub Actions / Jenkins |
| CD | ArgoCD |
| Package Management | Helm |
| Autoscaling | Karpenter / HPA |
| Database | PostgreSQL / Amazon RDS |
| DB Operator | CloudNativePG |
| Storage | Amazon EBS CSI |
| Monitoring | OpenTelemetry / Prometheus |
| Network | VPC / Tailscale |
| On-Premise | VMware / Kubernetes |

## Terraform
Terraform 코드는 리소스의 생명주기에 따라 분리합니다

```bash
cloud/
├── bootstrap/
│
├── modules/
│
└── environments/
    ├── dev/
    │   ├── foundation/
    │   └── runtime/
    │
    └── prod/
        ├── foundation/
        └── runtime/
```

Bootstrap
Terraform Remote State 등 다른 인프라보다 먼저 생성되어야하는 리소스를 관리합니다.

Foundation
네트워크와 같이 변경 빈도가 낮고 지속적으로 유지되어야하는 기반 리소스를 관리합니다.

Runtime
EKS를 포함하여 개발 과정에서 생성 및 제거가 필요한 실행 환경을 관리합니다.

이 구조를 통해 개발 종료 시 모든 리소스 제거 대신 필요한 리소스만 선택적으로 종료할 수 있도록 구성했습니다.

---
## Terraform CI
Terraform 코드 변경 시 실제 인프라에 반영하기 전에 Github Actions에서 자동 검증합니다.

```bash
Pull Request
      |
      ↓
terraform fmt
      |
      ↓
terraform validate
      |
      ↓
    TFLint
      |
      ↓
Trivy IaC Scan
      |
      ↓
Github OIDC
      |
      ↓
AWS IAM Role Assume
      |
      ↓
terraform plan
```
CI에서는 실제 인프라를 변경하는 apply를 수행하지않고 변경 예정 사항만 검증하는 것을 목적으로 합니다.
AWS 인증은 Access key를 저장하는 대신 Github OIDC 기반 IAM Role Assume 방식을 사용했습니다.

---
## Kubernetes
Amazon EKS 기반 Kubernetes환경을 구축하고 다음 구성요소를 사용했습니다.
- ArgoCD
- Jenkins
- Helm
- EBS CSI driver
- Karpenter
- OpenTelemetry Collector

일반 워크로드는 Karpenter를 통해 필요 시 노드를 프로비저닝할 수 있도록 구성했고,
GPU 워크로드는 별도의 Amazon EKS Managed Node Group으로 분리했습니다.

---
## EKS ↔ On-Premise DB
DB 환경은 VMware 기반 온프레미스 Kubernetes 환경에 구성했습니다.

PostgreSQL은 CloudNativePG 기반 Primary/Replica 구조로 구성하여
Primary가 읽기/쓰기 요청을 처리하고 Replica가 데이터를 복제하도록 구성했습니다.

AWS EKS와 온프레미스 환경은 서로 다른 네트워크에 존재하기 때문에 직접 통신할 수 없었습니다.
이를 해결하기 위해 Tailscale을 이용한 사설 네트워크 연결을 구성했습니다.

```bash
EKS pod
      |
      ↓
tailscale proxy
      |
      | tailnet
      ↓  
On-Premise VM 
      |
      ↓
PostgreSQL
├─ Primary
└─ Replica
```
EKS 내부에는 Proxy Pod를 배치하고 다음 서비스 연결을 전달할 수 있도록 구성했습니다.
- 5432 : PostgreSQL
- 9090 : Prometheus
- 3100 : Loki
- 4317 : OpenTelemetry gRPC

이를 통해 DB를 인터넷에 직접 노출하지 않고 EKS에서 온프레미스 서비스에 접근할 수 있도록 구성했습니다.

---
## Cost Optimization
개발 환경은 항상 실행되는 서비스가 아니기 때문에 리소스를 상시 운영하지 않는 방향으로 구성했습니다.

주요 비용 최적화 항목은 다음과 같습니다.
- GPU Node 기본 실행 수 0
- GPU 사용시에만 Terraform으로 Managed Node Group을 확장
- GPU Node 최대 1대로 제한
- Terraform foundation/runtime 분리
- 개발 종료 시 runtime 리소스 선택적 제거
- RDS 필요 시  stop/start 구조

---
## 트러블슈팅
프로젝트 진행 과정에서 다음과 같은 인프라 이슈가 있었습니다.

### EKS Access
팀원이 EKS Cluster에 접근하지 못하는 문제가 발생하여
EKS Access Entry와 Cluster Access Policy를 구성했습니다.

### Jenkins PVC
Jenkins PVC가 Pending 상태에 머무르는 문제를 확인하고
EBS CSI Driver 및 IAM 권한 구성을 점검했습니다.

### GPU Instance
GPU Node 생성 과정에서 EC2 Service Quota 제한으로
g4dn.xlarge 인스턴스 생성이 실패하는 문제가 발생했습니다.
Service Quota를 확인하고 GPU 계열 vCPU 할당량을 조정하여 해결했습니다.

### Hybrid Network
AWS EKS와 On-Premise VMware가 서로 다른 네트워크에 위치하여
직접 통신할 수 없는 문제를 Tailscale 기반 사설 네트워크로 해결했습니다.

---
## Key point
Pantry-Mate 인프라에서는 단순한 리소스 생성보다
개발 환경에서 실제로 운영하고 관리할 수 있는 구조를 만드는 것을 목표로 했습니다.

- Terraform 기반 AWS 인프라 코드화
- 리소스 생명주기를 고려한 Terraform 구조 분리
- Github Actions 기반 IaC 사전 검증
- Amazon EKS 기반 Kubernetes 환경 구축
- Managed Node Group 기반 GPU node 구성
- GPU Node 기본 실행 수 0을 통한 상시 운영 비용 절감
- EKS와 On-premise 환경 간 사설 네트워크 구축
- 팀 단위 EKS 접근 권한 관리