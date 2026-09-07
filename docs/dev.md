## Dev
Terraform으로 AWS 인프라를 모듈화해서 구성했습니다

environments에서 dev와 prod로 나뉘며, 둘다 동일한 Module을 사용합니다
환경변수 값은 terraform.tfvars에서 관리하도록 구성했습니다

아래는 /dev cli에서
terraform init 
terraform fmt
terraform validate
terraform plan
terraform apply

추가로 로컬에서 테스트하기 앞서 .tfvars에서 2가지 설정 하셔야 합니다
eks_endpoint_public_access = true                # true : 로컬 kubectl 접근을 위해 public endpoint 임시 허용 / 접근 cidr은 개발자 공인 ip로 제한
eks_public_access_cidrs    = ["자기.집.아이피.입력/32"] # 로컬 개발 시 curl ifconfig.me해서 나온 아이피 입력하기
