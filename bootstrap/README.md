# Terraform Bootstrap

## Bootstrap 역할

이 디렉터리는 Pantry Mate 서비스 인프라와 분리된 Terraform remote state용 S3
bucket을 관리합니다. Application S3 bucket과는 목적과 state가 완전히 분리됩니다.

Bootstrap 자신의 state는 생성 대상 S3 bucket에 저장하지 않고 이 디렉터리의 local
state로 유지합니다. `terraform.tfstate`와 관련 backup 파일은 Git에 포함되지
않습니다. 해당 local state는 암호화된 별도 저장소에 안전하게 백업해야 합니다.

생성되는 state object의 경로는 각 environment의 backend 설정으로 결정됩니다.

```text
Terraform State Bucket
├── dev/foundation/terraform.tfstate
├── dev/runtime/terraform.tfstate
├── prod/foundation/terraform.tfstate
└── prod/runtime/terraform.tfstate
```

S3 backend의 native lockfile을 사용하므로 DynamoDB table은 만들지 않습니다.
`use_lockfile` 사용을 위해 Terraform `1.10.0` 이상이 필요합니다.

## 최초 실행 순서

```bash
cd cloud/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`의 `terraform_state_bucket_name`을 전역적으로 고유한 이름으로
변경한 다음 실행합니다.

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Plan에서 state 전용 S3 리소스만 생성되는지 사용자가 검토한 후 직접 적용합니다.

```bash
terraform apply tfplan
```

Bucket에는 `prevent_destroy = true`와 `force_destroy = false`가 설정되어 있습니다.
Bootstrap을 제거해야 할 때도 state 보존 여부를 먼저 확인해야 합니다.

## Environment State

환경별 실행 순서와 기존 단일 State 분리 절차는
[`../README.md`](../README.md)와
[`../docs/state-migration.md`](../docs/state-migration.md)를 참고합니다.

## 주의사항

- `terraform apply`, `terraform destroy`, `terraform state rm`, resource import는
  검토 없이 실행하지 않습니다.
- State migration 전에 원본 State backup과 각 대상 backend key를 반드시 확인합니다.
- DEV와 PROD가 동일한 state key를 사용하면 안 됩니다.
- Bootstrap local state를 분실하면 state bucket 관리가 어려워지므로 별도로
  안전하게 백업합니다.
