## Dev
Terraform으로 AWS 인프라를 모듈화해서 구성했습니다.

DEV는 lifecycle에 따라 두 Root Module로 나뉩니다.

- `environments/dev/foundation`: Network, RDS
- `environments/dev/runtime`: NAT Instance, IAM, EKS, ECR, Application S3, Logs

S3 remote backend key는 각각 `dev/foundation/terraform.tfstate`와
`dev/runtime/terraform.tfstate`입니다. Runtime은 Foundation remote state의
Network Output을 참조합니다.


로컬에서 테스트하기 전 Runtime의 `terraform.tfvars`에서 다음 두 값을 제한적으로
설정합니다.

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
│   │   └── runtime/
│   │       ├── NAT Instance
│   │       ├── IAM
│   │       ├── EKS
│   │       ├── ECR
│   │       ├── Application S3
│   │       └── CloudWatch
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
    └── rds/
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
├── ECR
├── Application S3
└── CloudWatch
```

비용 관리를 위해 구분지었습니다
runtime은 foundation에서 생성한 vpc/subnet정보를
terraform remote state를 통해 참조합니다

runtime에서 vpc를 중복 생성하지 않아요

# 최초 구성
bootstrap apply -> foundation apply -> runtime apply

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
기본은 db.t4g.medium, Single-AZ, 100기가 입니다

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

## Destroy

foundation 부수면 RDS가 사라집니다 = 데이터 삭제됨

runtime만 일단 destroy하고

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
EKS / Application 테스트
순서로 실행합니다

# 패치 1 9/8
## 접속 방법
boankey.pem을 들고 .ssh 폴더에 집어넣습니다

terraform output에서 나온 nat ip와
kubectl get nodes -o wide 에서 나온 internal ip로

ssh -i ~/.ssh/boankey.pem \
  -o "ProxyCommand=ssh -i ~/.ssh/boankey.pem -W %h:%p ubuntu@<NAT_PUBLIC_IP>" \
  ubuntu@<NODE_PRIVATE_IP>

여기에 기입해서 접속합니다

ssh -i ~/.ssh/boankey.pem \
  ubuntu@<NAT_PUBLIC_IP>

# 패치 2 9/10
## ubuntu
원래 ubuntu로 진행했어야했는데 amazon linux로 생성되어있었습니다
ubuntu로 생성되도록 수정했습니다
