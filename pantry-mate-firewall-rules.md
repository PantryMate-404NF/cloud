# pantry-mate 방화벽 규칙 정리

## 1. NAT Instance Security Group

| 방향 | 프로토콜/포트 | 소스/대상 | 용도 |
|------|-------------|-----------|------|
| IN | ALL | 10.0.11.0/24, 10.0.12.0/24 | Private subnet 트래픽 수신 |
| OUT | ALL | 0.0.0.0/0 | 인터넷으로 마스커레이딩 후 전달 |

---

## 2. Lambda (Webhook Relay) Security Group

| 방향 | 프로토콜/포트 | 소스/대상 | 용도 |
|------|-------------|-----------|------|
| OUT | TCP 8080 | 10.0.0.0/16 (VPC CIDR) | Jenkins NLB로 포워딩 |
| OUT | TCP 443 | 0.0.0.0/0 | SSM Parameter Store API 호출 |

> Lambda는 VPC 내부에서 실행 → IN 규칙 불필요 (API Gateway가 트리거)

---

## 3. EKS Cluster Security Group

| 방향 | 프로토콜/포트 | 소스/대상 | 용도 |
|------|-------------|-----------|------|
| IN | TCP 8080 | Lambda-SG | Jenkins NLB webhook 수신 |
| IN | TCP 443 | 개발자 공인 IP/32 | kubectl, EKS API 접근 |
| IN | ALL | self (같은 SG) | 노드 간 내부 통신 |
| OUT | ALL | 0.0.0.0/0 | ECR pull, AWS API 등 |

> `eks_public_access_cidrs`에 개발자 공인 IP 입력 (`curl ifconfig.me`로 확인)

---

## 4. API Gateway (관리형, SG 없음)

- 별도 설정 불필요 — 퍼블릭 엔드포인트 자동 제공
- GitHub webhook IP 허용 불필요 (API Gateway가 자동 수신)
- 인증은 **HMAC-SHA256 서명 검증**(Lambda handler.py)으로만 처리

---

## 5. Tailscale — EKS 아웃바운드

EKS 노드/Pod에서 아웃바운드만 열면 됨:

| 방향 | 프로토콜/포트 | 대상 | 용도 |
|------|-------------|------|------|
| OUT | UDP 41641 | 0.0.0.0/0 | Tailscale DERP/P2P 터널 |
| OUT | TCP 443 | 0.0.0.0/0 | Tailscale 제어 서버 (HTTPS fallback) |

---

## 6. 온프레미스 방화벽 (인바운드)

### Tailscale 연결

| 방향 | 프로토콜/포트 | 소스 | 용도 |
|------|-------------|------|------|
| IN | UDP 41641 | 0.0.0.0/0 | Tailscale P2P 수신 |

### 모니터링 수신 (Tailscale 터널 내부, 가상 IP 기준)

| 방향 | 프로토콜/포트 | 소스 | 용도 |
|------|-------------|------|------|
| IN | TCP 9090 | Tailscale EKS IP | Prometheus (OTel Collector → Prometheus) |
| IN | TCP 3100 | Tailscale EKS IP | Loki (OTel Collector → Loki) |
| IN | TCP 4317 | Tailscale EKS IP | Tempo gRPC (OTel Collector → Tempo) |

### DB 수신 (Tailscale 터널 내부, 가상 IP 기준)

| 방향 | 프로토콜/포트 | 소스 | 용도 |
|------|-------------|------|------|
| IN | TCP 5432 | Tailscale EKS IP | PostgreSQL / PGBouncer |
| IN | TCP 27017 | Tailscale EKS IP | MongoDB |

---

## 7. Cloudflare Tunnel — EKS 아웃바운드

| 방향 | 프로토콜/포트 | 대상 | 용도 |
|------|-------------|------|------|
| OUT | TCP 7844 | Cloudflare IP 대역 | cloudflared → Cloudflare edge (HTTPS) |
| OUT | UDP 7844 | Cloudflare IP 대역 | cloudflared → Cloudflare edge (QUIC) |
| IN | TCP 443 | cloudflared (클러스터 내부) | Cloudflare → 앱 서비스로 트래픽 전달 |

> 외부 인바운드 불필요 — cloudflared가 아웃바운드로 터널을 맺고, Cloudflare edge가 그 터널을 통해 내부 서비스(TCP 443)로 트래픽을 밀어넣음 → 공개 IP/ALB 불필요

---

## 요약: 실제로 공인 인바운드를 열어야 하는 곳

| 위치 | 열어야 할 것 | 비고 |
|------|------------|------|
| **API Gateway** | 자동 (관리형) | 별도 설정 없음 |
| **EKS API 엔드포인트** | TCP 443, 개발자 공인 IP/32 | `eks_public_access_cidrs`에 설정 |
| **온프레미스 방화벽** | UDP 41641 (Tailscale) | 나머지는 터널 내부 통신 |
| **NAT Instance EIP** | 아웃바운드 전용, 인바운드 불필요 | AWS 자동 할당 |

> 퍼블릭 인바운드 구멍은 **EKS API(개발자 IP 전용)** 와 **Tailscale UDP 41641(온프레미스)** 두 곳뿐.  
> 나머지는 모두 아웃바운드 연결 또는 VPC 내부 SG 참조로 처리됨.
