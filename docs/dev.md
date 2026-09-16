## Dev
Terraform으로 AWS 인프라를 모듈화해서 구성했습니다.

ubuntu입니다.

DEV는 lifecycle에 따라 세 Root Module로 나뉩니다.

- `environments/dev/foundation`: Network, RDS
- `environments/dev/runtime`: NAT Instance, IAM, EKS, ECR, Application S3, Logs
- `environments/dev/autoscaling`: Metrics Server, KEDA, Karpenter

`environments/dev/cloudflared`는 terraform root module이 아니라
Cloudflare Tunnel을 구성하기 위한 별도 Kubernetes Manifest입니다.

runtime은 foundation Remote State의 Network Output을 참조하며,
autoscaling은 runtime에서 생성된 EKS Cluster를 기준으로 구성됩니다.

S3 remote backend key는 각각 `dev/foundation/terraform.tfstate`와
`dev/runtime/terraform.tfstate`입니다. Runtime은 Foundation remote state의
Network Output을 참조합니다.

기본 runtime 구성에는 EKS Private Endpointㄹ르 사용합니다.

로컬 pc에서 `kubectl`로 EKS API에 직접 접근해야 하는 경우에만 runtime의 `terraform.tfvars`에서
public endpoint를 임시 활성화합니다.

```hcl
eks_endpoint_public_access = true   # true : 로컬 kubectl 접근을 위해 public endpoint 임시 허용 / 접근 cidr은 개발자 공인 ip로 제한
eks_public_access_cidrs    = ["자기.집.아이피.입력/32"] # 로컬 개발 시 curl ifconfig.me해서 나온 아이피 입력하기
```

`0.0.0.0/0`은 사용하지 않습니다.

## Terraform 구조

Pantry Mate DEV Terraform은 Resource의 생명주기에 따라
`bootstrap`, `foundation`, `runtime`으로 분리되어 있습니다.

```text
cloud/
├── bootstrap/
│   └── Terraform Remote State 저장소 관리
│
├── environments/
│   ├── dev/
│   │   ├── foundation/
│   │   │   ├── Network
│   │   │   └── RDS
│   │   │
│   │   ├── runtime/
│   │   │   ├── NAT Instance
│   │   │   ├── IAM
│   │   │   ├── EKS
│   │   │   ├── ECR
│   │   │   ├── Application S3
│   │   │   └── CloudWatch
│   │   │
│   │   ├── autoscaling/
│   │   │
│   │   └── cloudflared/
│   │
│   └── prod/
│       ├── foundation/
│       └── runtime/
│
└── modules/
    ├── network/
    ├── nat-instance/
    ├── iam/
    ├── eks/
    ├── ecr/
    ├── storage/
    ├── observability/
    ├── rds/
    ├── jenkins/
    ├── webhook-relay/
    ├── argocd/
    ├── karpenter/
    └── keda/
```

## bootstrap

bootstrap 자체 state는 local state를 사용합니다.

terraform state s3 내부에서는 환경과 lifecycle 별로 state를 분리했습니다.
```bash
Terraform State S3

├── dev/foundation/terraform.tfstate
├── dev/runtime/terraform.tfstate
├── prod/foundation/terraform.tfstate
└── prod/runtime/terraform.tfstate
```

# RDS stop 구조를 위한 분리

## dev foundation
destroy하지않고 유지할 기반 리소스를 관리합니다.

```bash
Foundation
├── VPC
├── Public Subnet
├── Private Subnet
├── Internet Gateway
├── Route Table
├── RDS DB Subnet Group
├── RDS Security Group
└── PostgreSQL RDS
```

RDS 데이터 유지를 위해 destroy X
대신 RDS 비용 절감을 위해 DB는 삭제하지않고 Stop / Start

## dev runtime
필요할 때 생성하고 테스트 종료 후 삭제할 수 있는 리소스를 관리합니다.

```bash
Runtime
├── NAT Instance
├── EKS Cluster
├── EKS Managed Node Group
├── IAM
├── Jenkins
├── Jenkins Internal NLB
├── Github webhook relay
├── ArgoCD
├── ECR
├── Application S3
└── CloudWatch
```

비용 관리를 위해 구분지었습니다
runtime은 foundation에서 생성한 vpc/subnet정보를
terraform remote state를 통해 참조합니다

runtime에서 vpc를 중복 생성하지 않아요

## dev autoscaling
runtime에서 생성된 EKS Cluster를 기준으로 Cluster Autoscaling 관련 구성을 관리합니다.
```bash
Autoscaling
├── Metrics Server
├── KEDA
└── Karpenter
```
runtime이 먼저 구성되어 있어야 Autoscaling구성을 적용할 수 있습니다.

## Cloudflare Tunnel
`environmnets/dev/cloudflared`는 terraform에서 직접 관리하지않는
별도 Kubernetes Manifest입니다.

현재 application service는 `ClusterIP`이며,
외부 공개가 필요한 경우 Cloudflare Tunnel를 통해 접근합니다.

runtime과 autoscaling 구성이 완료된 이후 별도로 manifest를 적용합니다.

# 최초 구성
bootstrap apply
-> foundation apply
-> runtime apply
-> EKS 접속 및 상태 확인
-> autoscaling apply
-> cloudflared manifest 적용
-> 잘 적용되어있는지 확인

## bootstrap

terraform --version
기준은 1.15.x 입니다

aws sts get-caller-identity
프로비저닝할 계정 확인하시고

bootstrap 폴더 안에 terraform.tfvars 하나 만듭니다
terraform_state_bucket_name = "pantry-mate-tstate-여러개의 숫자-apne2"
숫자는 본인 account나 넣고싶은 숫자 많이 넣으시면 됩니다 (중복된 이름의 state는 만들어지지않음)

이후
cd ~/cloud/bootstrap 에서
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply < 최초 1회가 될거에요

## dev foundation

cd cloud/environments/dev/foundation 에서

먼저 backend.hcl을 만들어줍니다 << example 있어요
거기서:
bucket       = "CHANGE_ME_TO_BOOTSTRAP_BUCKET_NAME"
이 부분에 bootstrap의 bucket name을 집어 넣으면 됩니다 -> "pantry-mate-tstate-여러개의 숫자-apne2"

그리고 foundation폴더 내에서 terraform.tfvars 만들어줍니다 << example 있어요
기본 RDS구성은 db.t4g.medium, Single-AZ, 100GiB 입니다
기본 AZ는 `ap-northeast-2a`입니다.

배치 AZ는 `rds_availability_zone` 변수로 변경 가능합니다.

다음으로
terraform init \
    -backend-config=backend.hcl
hcl 기반으로 init해주고

terraform fmt -check
terraform validate
terraform plan
terraform apply < 이것도 아마 최초 1회

후에
aws rds describe-db-instances \
    --region ap-northeast-2

여기서 available 되면 다음 runtime으로

## dev runtime

cd cloud/environmnets/dev/runtime 에서

여기도 backend.hcl을 만들어줍니다 << example 있어요
마찬가지로 
bucket       = "CHANGE_ME_TO_BOOTSTRAP_BUCKET_NAME"
이 부분에 bootstrap의 bucket name을 집어 넣으면 됩니다 -> "pantry-mate-tstate-여러개의 숫자-apne2"

terraform.tfvars도 만들어줍니다 << example 있어요
여기서 node 갯수 및 instance 사이즈 변경 가능하구요
bucket name도 적어주세요

terraform init \
    -backend-config=backend.hcl
hcl 기반으로 init해주고

terraform fmt -check
terraform validate
terraform plan
여기서 vpc subnet rds가 나오면 안됩니다

terraform apply

적용 완료 후 EKS 접속 정보를 갱신해줍시다.
```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name pantry-mate-dev-eks
```

## Destroy

foundation 부수면 RDS가 사라집니다 = 데이터 삭제됨

환경 종료 시 autoscaling부터 제거합니다.

cloudflare도 제거해줍니다
```bash
kubectl delete -f environments/dev/cloudflared
```

이후 runtime destroy합니다.
runtime에는 ECR 및 application S3가 포함되있기에
destroy하기전에 보존해야하는 이미지나 데이터가 있는지 확인해야합니다.

RDS stop하기
aws rds describe-db-instances \
  --region ap-northeast-2 \
  --query 'DBInstances[].DBInstanceIdentifier' \
  --output table
여기서 나온 
-----------------------------
|     DescribeDBInstances   |
+---------------------------+
|  pantry-mate-dev-postgres |
+---------------------------+
의 값을 아래에 넣고 stop
aws rds stop-db-instance \
  --region ap-northeast-2 \
  --db-instance-identifier <DEV_RDS_IDENTIFIER>

다시 시작하려면
aws rds start-db-instance \
  --region ap-northeast-2 \
  --db-instance-identifier <DEV_RDS_IDENTIFIER>
하시면 됩니다


## 요약하자면
Repository Clone
      ↓
Terraform Version 확인
      ↓
AWS Account 확인
      ↓
State S3 Bucket 이름 확인
      ↓
Foundation backend.hcl 생성
      ↓
Foundation terraform.tfvars 생성
      ↓
Foundation init
      ↓
Foundation validate
      ↓
Foundation plan 확인
      ↓
Foundation apply
      ↓
RDS available 확인
      ↓
Runtime backend.hcl 생성
      ↓
Runtime terraform.tfvars 생성
      ↓
Runtime init
      ↓
Runtime validate
      ↓
Runtime plan 확인
      ↓
Runtime apply
      ↓
EKS 접속 확인
      ↓
node/pod 상태 확인
      ↓
autoscaling init/plan/apply
      ↓
Metrics Server/KEDA/Karpenter 확인
      ↓
Cloudflared manifest 적용
      ↓
application 외부 접근 확인


## EKS node ssh 접속
Developer
-> NAT instance
-> EKS node private ip

boankey.pem을 들고 .ssh 폴더에 집어넣습니다

terraform output에서 나온 nat ip와
kubectl get nodes -o wide 에서 나온 internal ip로

ssh -i ~/.ssh/boankey.pem \
  -o "ProxyCommand=ssh -i ~/.ssh/boankey.pem -W %h:%p ubuntu@<NAT_PUBLIC_IP>" \
  ubuntu@<NODE_PRIVATE_IP>

여기에 기입해서 접속합니다

ssh -i ~/.ssh/boankey.pem \
  ubuntu@<NAT_PUBLIC_IP>

