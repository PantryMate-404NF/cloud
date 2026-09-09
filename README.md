# Welcome to your organization's demo repository

This code repository (or "repo") is designed to demonstrate the best GitHub has to offer with the least amount of noise.

The repo includes an `index.html` file (so it can render a web page), two GitHub Actions workflows, and a CSS stylesheet dependency.

## Pantry Mate Infrastructure as Code

Pantry Mate AWS Terraform은 Resource lifecycle에 따라 Bootstrap, Foundation,
Runtime의 독립적인 Root Module과 State로 관리합니다.

```text
cloud/
├── bootstrap/                  # Terraform remote-state S3 bucket
├── environments/
│   ├── dev/
│   │   ├── foundation/         # Network + PostgreSQL RDS
│   │   └── runtime/            # NAT, IAM, EKS, ECR, App S3, Logs
│   └── prod/
│       ├── foundation/         # 구조만 준비됨; 사양 확정 전
│       └── runtime/            # 구조만 준비됨; 사양 확정 전
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

## Bootstrap

`bootstrap`은 Terraform State용 S3 bucket만 관리합니다. 자체 State는 Local State로
유지하며 Backend bucket, Public Access Block, Ownership, Versioning, 암호화,
SecureTransport 정책을 생성합니다. Bucket resource에는 `prevent_destroy = true`가
설정되어 있습니다.

## Foundation

Foundation은 Runtime을 반복 생성·삭제해도 유지해야 하는 리소스를 관리합니다.

- VPC, Public/Private subnet, Internet Gateway, Route Table
- RDS DB Subnet Group과 Security Group
- Private PostgreSQL RDS

DEV RDS 비밀번호는 코드나 tfvars로 받지 않습니다. RDS의
`manage_master_user_password`를 사용해 Secrets Manager에 저장합니다.

## Runtime

Runtime은 개발 세션에 맞춰 생성·삭제할 수 있는 리소스를 관리합니다.

- NAT Instance와 Elastic IP
- EKS Cluster, Managed Node Group, EKS IAM
- ECR
- Application S3
- CloudWatch log group

Runtime은 `terraform_remote_state`로 Foundation의 VPC/Subnet/Route Table Output을
읽으며 Network module을 다시 호출하지 않습니다. ECR의 `force_delete`와 Application
S3의 `force_destroy`는 기존과 동일하게 `false`입니다.

## State Layout

```text
Terraform State S3 Bucket
├── dev/foundation/terraform.tfstate
├── dev/runtime/terraform.tfstate
├── prod/foundation/terraform.tfstate
└── prod/runtime/terraform.tfstate
```

실제 `backend.hcl`과 `terraform.tfvars`는 Git에서 제외합니다. 각 디렉터리의
`.example`을 복사한 뒤 실제 bucket 이름과 환경 값을 입력합니다.

## 실행 순서

1. `bootstrap`
2. `environments/dev/foundation`
3. `environments/dev/runtime`

Foundation apply가 성공하고 State Output이 생성된 뒤에만 Runtime을 실행합니다.
State 분리 전에는 [`docs/state-migration.md`](docs/state-migration.md)를 먼저 확인합니다.

## 개발 종료 순서

1. DEV Runtime을 destroy합니다.
2. DEV RDS를 수동으로 stop합니다.
3. DEV Foundation은 유지합니다.

RDS stop은 최대 7일 뒤 AWS가 자동으로 다시 시작할 수 있으므로 상태와 비용을
주기적으로 확인해야 합니다. 자동 Start/Stop Scheduler는 현재 범위에 포함하지
않으며, 후속 작업에서는 Runtime이 아닌 별도 `operations` Root Module 또는
Foundation과 분리된 automation module로 구성하는 것을 권장합니다.

> **주의:** Foundation destroy는 VPC와 RDS 데이터 수명에 직접 영향을 줍니다.
> 일반적인 개발 종료 작업에서 Foundation에 `terraform destroy`를 실행하지 마세요.

## PROD

PROD는 Foundation/Runtime 디렉터리와 Backend key, 공통 변수 구조만 준비되어
있습니다. RDS Multi-AZ, NAT 방식, EKS node 수와 instance type, backup/deletion
정책이 승인되기 전까지 DEV 구성을 복제하지 않습니다.
