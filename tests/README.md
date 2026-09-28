# Pantry-Mate Cloud Infrastructure Test Suite

Pantry-Mate 하이브리드 클라우드 환경의 **AutoScaling, 부하 테스트, 장애 복구, HA, SLO/Error Budget, 백업·복원, 비용**을 검증하기 위한 테스트 스크립트 모음입니다.

본 테스트 환경은 다음 구조를 기준으로 합니다.

```text
Client / k6
     │
     ▼
Cloudflare
     │
     ▼
AWS EKS
 ├─ Frontend
 ├─ Gateway
 ├─ User
 ├─ Product
 ├─ Order-Payment
 ├─ Pantry-Recipe
 └─ Notification
     │
     ├─ KEDA
     │    └─ Pod AutoScaling
     │
     ├─ Karpenter
     │    └─ Node AutoScaling
     │
     └─ OTel Collector
           │
           ▼
     On-Premise
     ├─ Prometheus
     └─ PostgreSQL
```

---

# 1. 테스트 목적

본 테스트의 주요 목적은 다음과 같습니다.

### AutoScaling

- 부하 증가에 따른 KEDA Pod Scale-out 검증
- Pod 증가에 따른 리소스 부족 상황에서 Karpenter Node Scale-out 검증
- 부하 종료 후 Pod Scale-in 검증
- Karpenter Node Consolidation 및 Node 회수 검증

### 장애 복구 / HA

- Pod 장애 발생 시 자동 복구 검증
- CPU 부하 발생 시 AutoScaling 동작 검증
- Node Drain 상황에서 Pod 재배치 검증
- 서비스 복구 시간(RTO) 측정

### SLO

- k6 부하테스트 기반 Availability 측정
- Error Budget 계산
- Burn Rate 계산
- Prometheus 기반 30일 Rolling SLO 측정 기준 제공

### Backup / Restore

- PostgreSQL/CNPG Backup 상태 확인
- RDS Snapshot 상태 확인
- Restore 후 DB Query 성공까지 복원 시간 측정
- 테스트 데이터 기반 RPO 검증

### Cost

- AWS Cost Explorer 기반 실제 비용 수집
- EC2/RDS 리소스 확인
- 예상 월 비용 계산
- 장기 비용 시나리오 계산

---

# 2. 디렉터리 구조

```text
tests/
├── README.md
├── config.env
├── config.local.env
├── run-autoscaling-test.sh
│
├── lib/
│   └── common.sh
│
├── baseline/
│   └── collect.sh
│
├── load/
│   ├── all-services.js
│   └── run.sh
│
├── observe/
│   ├── health-check.sh
│   ├── watch.sh
│   ├── watch-db.sh
│   └── collect-events.sh
│
├── failure/
│   ├── pod-kill.sh
│   ├── cpu-stress.sh
│   └── node-failure.sh
│
├── ha/
│   ├── collect-cnpg-status.sh
│   ├── measure-rto.sh
│   └── watch-recovery.sh
│
├── backup/
│   ├── check-cnpg-backup.sh
│   ├── check-rds-snapshot.sh
│   └── measure-restore.sh
│
├── slo/
│   └── calculate-slo.py
│
├── cost/
│   ├── collect-aws-cost.sh
│   ├── estimate-monthly-cost.py
│   ├── forecast-cost.py
│   └── rates.example.json
│
└── results/
```

---

# 3. 사전 요구사항

테스트 실행 서버에서 다음 도구를 사용할 수 있어야 합니다.

```bash
kubectl
jq
k6
python3   # 3.9 이상. Windows Git Bash에서는 python3가 스토어 연결 파일이라 python을 자동으로 사용
aws
```

`k6`와 `jq`는 기본 설치되어 있지 않은 경우가 많습니다. Windows 예: `winget install k6.k6 jqlang.jq`

CNPG 관련 스크립트(`ha/collect-cnpg-status.sh`, `backup/check-cnpg-backup.sh`)는 **온프레미스 쿠버네티스 kubeconfig**가 추가로 필요합니다(4.1 참고).

Kubernetes 접근 확인:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n app
```

Metrics API 확인:

```bash
kubectl top nodes
kubectl top pods -n app
```

KEDA 확인:

```bash
kubectl get scaledobject -n app
kubectl get hpa -n app
```

Karpenter 확인:

```bash
kubectl get nodepool
kubectl get nodeclaim
```

---

# 4. 환경 설정

공통 기본 설정은 다음 파일을 사용합니다.

```text
config.env
```

환경별 실제 값은 다음 파일에 설정합니다.

```text
config.local.env
```

`config.local.env`는 테스트 환경마다 달라질 수 있는 URL 및 설정을 저장하기 위한 파일입니다. 예시 파일을 복사해서 사용합니다.

```bash
cp config.local.env.example config.local.env
```

## 4.1 온프레미스 클러스터(CNPG) 접근

DB는 EKS가 아니라 온프레미스에 있습니다.

```text
EKS 앱 → tailscale-proxy(EKS, monitoring) → Tailscale → VM1(k8s: 모니터링, CNPG) → VM2(PostgreSQL)
```

그래서 기본 kubectl context(EKS)로는 CNPG가 조회되지 않습니다. CNPG 스크립트는 `ONPREM_KUBE_CONTEXT`에 지정한 context로만 실행됩니다.

1. VM1의 kubeconfig(`/etc/kubernetes/admin.conf` 등)를 받아 `server:` 주소를 VM1의 Tailscale IP로 바꿉니다.
2. 로컬 kubeconfig에 병합한 뒤 context 이름을 확인합니다: `kubectl config get-contexts`
3. `config.local.env`에 설정합니다.

```bash
ONPREM_KUBE_CONTEXT=<온프레미스 context 이름>
DB_NAMESPACE=<VM1에서 kubectl get cluster -A 로 확인한 네임스페이스>
CNPG_CLUSTER=<같은 명령의 NAME>
```

---

# 5. 테스트 URL 설정

현재 Kubernetes Application Service는 모두 `ClusterIP` 방식입니다.

```text
frontend
pantry-mate-frontend.app.svc:3000

gateway
pantry-mate-gateway.app.svc:8080

user
pantry-mate-user.app.svc:8081

pantry-recipe
pantry-mate-pantry-recipe.app.svc:8082

product
pantry-mate-product.app.svc:8083

order-payment
pantry-mate-order-payment.app.svc:8084

notification
pantry-mate-notification.app.svc:8085
```

단, 실제 부하테스트에서는 테스트 목적에 따라 URL을 구분해야 합니다.

## 5.1 사용자 트래픽 기반 테스트

실제 사용자 요청 경로를 최대한 재현합니다.

```text
k6
 ↓
Cloudflare
 ↓
Frontend / Gateway
 ↓
Backend
```

이 방식은 전체 서비스 경로와 AutoScaling 동작을 검증하는 데 사용합니다.

Cloudflare Hostname 및 Gateway API Route를 확인한 후 `config.local.env`에 실제 URL을 설정합니다.

---

## 5.2 내부 서비스 직접 테스트

특정 Microservice만 집중적으로 부하 테스트해야 하는 경우 Kubernetes Service를 직접 사용할 수 있습니다.

예:

```text
k6
 ↓
pantry-mate-product
 ↓
Product Pods
```

이 방식은 특정 서비스의 KEDA Scale-out 임계치 및 리소스 사용량을 검증하는 데 적합합니다.

단, k6 실행 위치에서 Kubernetes Service DNS에 접근할 수 있어야 합니다.

---

# 6. 전체 AutoScaling 테스트

메인 테스트 Runner:

```bash
./run-autoscaling-test.sh
```

전체 흐름:

```text
STEP 1
Pre-flight Health Check
        │
        ▼
STEP 2
Baseline 수집
        │
        ▼
STEP 3
초기 Kubernetes Event 수집
        │
        ▼
STEP 4
HPA / Pod / Node / DB Monitoring 시작
        │
        ▼
STEP 5
k6 Load Test
        │
        ▼
STEP 6
Scale-in / Node Consolidation 관찰
        │
        ▼
STEP 7
최종 Baseline 수집
        │
        ▼
STEP 8
최종 Event 수집
        │
        ▼
Results 저장
```

테스트 결과는 다음 경로에 저장됩니다.

```text
results/<TEST_ID>/
```

---

# 7. Pre-flight Health Check

실행:

```bash
./observe/health-check.sh
```

부하테스트 전에 다음 상태를 확인합니다.

- Deployment Ready Replica
- CrashLoopBackOff
- KEDA ScaledObject 상태
- KEDA Pause 여부
- HPA Metric 상태
- Metrics API
- NodePool / NodeClaim

다음과 같은 상태에서는 부하테스트를 진행하지 않습니다.

```text
Deployment Ready 부족
CrashLoopBackOff 존재
HPA <unknown>
KEDA Pause
Metrics API 장애
```

즉, 장애 상태에서 부하를 추가하여 테스트 결과가 왜곡되는 것을 방지합니다.

---

# 8. Baseline 수집

실행:

```bash
./baseline/collect.sh
```

다음 정보를 테스트 전후로 수집합니다.

```text
Node
Pod
Deployment
HPA
ScaledObject
NodeClaim
NodePool
Kubernetes Event
Pod Resource Usage
Node Resource Usage
```

이를 통해 테스트 전후의 인프라 상태를 비교합니다.

---

# 9. Load Test

실행:

```bash
./load/run.sh
```

실제 k6 시나리오는 다음 파일에 정의되어 있습니다.

```text
load/all-services.js
```

각 서비스별 독립적인 k6 Scenario가 생성됩니다.

예:

```javascript
stages: [
  { duration: '1m', target: 5 },
  { duration: '2m', target: 10 },
  { duration: '2m', target: 15 },
  { duration: '2m', target: 20 },
  { duration: '2m', target: 20 },
  { duration: '1m', target: 0 },
]
```

`target`은 Virtual User(VU) 수입니다.

예:

```text
1분 → 5 VU
2분 → 10 VU
2분 → 15 VU
2분 → 20 VU
2분 → 20 VU 유지
1분 → 0 VU
```

주의:

여러 서비스 URL을 동시에 설정하면 각 서비스 Scenario가 동시에 실행됩니다.

예를 들어 7개 서비스 × 최대 20 VU이면 이론상 최대:

```text
140 VU
```

가 동시에 동작할 수 있습니다.

따라서 최초 테스트는 낮은 부하에서 시작한 후 단계적으로 증가시키는 것을 권장합니다.

---

# 10. AutoScaling 관찰

테스트 중 다음 스크립트가 Kubernetes 상태를 지속적으로 기록합니다.

```bash
./observe/watch.sh
```

주요 관찰 대상:

```text
HPA
Deployment
Pod
Node
NodeClaim
Pod CPU/Memory
Node CPU/Memory
```

관찰 흐름:

```text
Load 증가
   ↓
Pod CPU / Memory 증가
   ↓
KEDA / HPA Desired Replica 증가
   ↓
Pod Scale-out
   ↓
Node Resource 부족
   ↓
Pending Pod 발생 가능
   ↓
Karpenter NodeClaim 생성
   ↓
EC2 Node Provisioning
   ↓
Pending Pod Scheduling
```

부하 종료 후:

```text
Load 감소
   ↓
HPA Scale-down Stabilization
   ↓
Pod Scale-in
   ↓
Node Underutilized
   ↓
Karpenter Consolidation
   ↓
Node 회수
```

---

# 11. DB 장애 감시

실행:

```bash
./observe/watch-db.sh
```

Backend 서비스의 DB 관련 오류를 지속적으로 수집합니다.

대상 서비스:

```text
notification
order-payment
pantry-recipe
product
user
```

주요 감시 패턴:

```text
remaining connection slots
too many clients
connection attempt failed
unable to obtain connection
PSQLException
HikariPool
SocketTimeoutException
Read timed out
```

부하테스트 중 DB Connection Pool 고갈이나 PostgreSQL 연결 장애가 발생했는지 확인하는 용도로 사용합니다.

---

# 12. 장애 주입 테스트

> 장애 주입은 정상 상태(Baseline Healthy)가 확인된 이후에만 수행합니다.

## 12.1 Pod Kill

```bash
DEPLOYMENT=pantry-mate-product \
./failure/pod-kill.sh
```

검증 항목:

```text
Pod 삭제
 ↓
Replica 감소
 ↓
Deployment 신규 Pod 생성
 ↓
Readiness 통과
 ↓
서비스 정상화
```

---

## 12.2 CPU Stress

```bash
POD=<POD_NAME> \
DURATION=60 \
./failure/cpu-stress.sh
```

애플리케이션 이미지에는 stress 도구가 없으므로, 같은 Pod에 **임시(ephemeral) 디버그 컨테이너**(`STRESS_IMAGE`, 기본 `alexeiled/stress-ng`)를 붙여 부하를 겁니다. `WORKERS`(1~4)로 CPU 워커 수, `CONTAINER`로 대상 컨테이너를 지정할 수 있습니다.

- 임시 컨테이너는 Pod가 재생성될 때까지 종료 상태로 기록이 남습니다(서비스 영향 없음).
- 임시 컨테이너에는 resources.requests가 없으므로, HPA의 CPU 사용률(요청량 대비)에 반영되는 방식은 클러스터 버전에 따라 다를 수 있습니다. KEDA/HPA 반응은 `kubectl get hpa -w`로 함께 확인합니다.

---

## 12.3 Node Failure Simulation

```bash
NODE=<NODE_NAME> \
./failure/node-failure.sh
```

현재 Node Failure Script는:

```text
cordon
+
drain
```

방식입니다.

따라서 이는 실제 EC2 Instance Power-Off 테스트가 아닙니다.

**`role=worker` 노드만 허용됩니다.** 아래 노드는 drain하면 테스트가 아니라 실제 장애가 되므로 스크립트가 거부합니다.

| role | 영향 |
|---|---|
| `tailscale` | 모든 백엔드의 DB 경로 차단 |
| `manage` | Jenkins, ArgoCD 중단 |
| `gpu` | AI 서버 중단 |

검증 항목:

```text
Node Scheduling 차단
 ↓
Pod Eviction
 ↓
다른 Node 재배치
 ↓
Readiness 회복
```

테스트 후:

```bash
kubectl uncordon <NODE_NAME>
```

---

# 13. RTO 측정

RTO:

```text
Recovery Time Objective
```

즉 장애 발생 후 실제 서비스가 정상적으로 다시 제공되기까지 걸린 시간입니다.

단순히 Pod가 `Running`이 되었다고 서비스가 복구된 것은 아닙니다.

DB(CNPG) 장애의 경우 온프레미스에서 CNPG가 failover를 끝냈더라도, EKS 앱이 `tailscale-proxy → VM1`을 거쳐 새 primary에 실제로 쿼리하기 전까지는 복구된 것이 아닙니다. VM1이 멈추면 VM2의 DB가 살아 있어도 EKS에서는 접근할 수 없습니다(VM1 단일 장애점).

가능하면 다음 기준을 사용합니다.

```text
장애 발생 시각
        ↓
Pod 재생성
        ↓
Readiness 성공
        ↓
Endpoint 등록
        ↓
실제 HTTP 요청 성공
        ↓
RTO 종료
```

시간 계산:

```bash
START=<장애발생시각> \
END=<서비스복구확인시각> \
./ha/measure-rto.sh
```

---

# 14. Backup / Restore

백업 관련 스크립트:

```text
backup/
├── check-cnpg-backup.sh
├── check-rds-snapshot.sh
└── measure-restore.sh
```

백업 리소스가 존재한다는 사실만으로 복원 가능성이 검증된 것은 아닙니다.

권장 검증 흐름:

```text
Test Data A 생성
      ↓
백업 / Snapshot
      ↓
Test Data B 생성
      ↓
Restore
      ↓
복원 DB 접속
      ↓
Query 실행
      ↓
Data A / B 확인
      ↓
RPO 판정
```

RTO는:

```text
Restore 요청 시각
      ↓
DB Restore
      ↓
DB Connection
      ↓
검증 Query 성공
```

구간으로 측정합니다.

---

# 15. SLO / Error Budget / Burn Rate

계산 스크립트:

```bash
python3 slo/calculate-slo.py \
  results/<TEST_ID>/k6-summary.json
```

Prometheus 운영 쿼리까지 출력:

```bash
python3 slo/calculate-slo.py \
  results/<TEST_ID>/k6-summary.json \
  --show-promql
```

---

## 15.1 Backend Availability SLO

목표:

```text
SLO = 99.9%
```

따라서:

```text
Error Budget
= 100% - 99.9%
= 0.1%
```

Burn Rate:

```text
Burn Rate
=
실제 실패율
────────────
허용 실패율
```

예:

```text
실제 실패율 = 0.2%
허용 실패율 = 0.1%

Burn Rate = 2.0x
```

---

## 15.2 AI Latency SLO

정의:

```text
Good Event
=
AI Response Time <= 3 sec
```

목표:

```text
99.0%
```

따라서:

```text
Error Budget = 1.0%
```

AI SLO를 정확히 계산하려면 AI 요청에 대한 별도 Metric이 필요합니다.

예:

```text
ai_requests
ai_latency_good
```

현재 해당 Metric이 없는 경우 전체 HTTP P95만으로 AI 99% SLO를 임의 계산하지 않습니다.

---

## 15.3 운영 Burn Rate

운영 SLO:

```text
Rolling Window = 30 days
```

Critical:

```text
1h Burn Rate > 14.4
```

Warning:

```text
6h Burn Rate > 6.0
```

중요:

```text
k6 Burn Rate
≠
30일 운영 Burn Rate
```

k6 결과는 **Test Window Burn Rate**입니다.

실제:

```text
30d SLO
1h Critical Burn Rate
6h Warning Burn Rate
```

는 Prometheus 시계열 데이터로 계산합니다.

---

# 16. Cost

AWS 비용 정보 수집:

```bash
./cost/collect-aws-cost.sh
```

예상 월 비용:

```bash
python3 cost/estimate-monthly-cost.py
```

장기 비용 시나리오:

```bash
python3 cost/forecast-cost.py
```

비용 계산은 실제 AWS 청구 비용과 Scenario 기반 예상 비용을 구분하여 사용합니다.

---

# 17. 결과 디렉터리

각 테스트 결과는 다음과 같이 관리합니다.

```text
results/
└── <TEST_ID>/
    ├── baseline-before/
    ├── baseline-after/
    ├── timeline.log
    ├── db-errors.log
    ├── k6.log
    ├── k6-summary.json
    └── events/
```

최종 보고서 작성 시 다음 증빙을 우선 사용합니다.

```text
1. 테스트 시작 전 Baseline
2. k6 부하 결과
3. HPA Replica 변화
4. KEDA Scale-out Event
5. Karpenter NodeClaim 생성
6. 신규 Node Provisioning
7. 부하 종료 후 Pod Scale-in
8. Karpenter Node Consolidation
9. DB Error 발생 여부
10. 테스트 종료 후 Baseline
```

---

# 18. 권장 테스트 순서

전체 테스트를 한 번에 강하게 수행하지 않습니다.

```text
Phase 1
Health Check

        ↓

Phase 2
낮은 부하 Smoke Test

        ↓

Phase 3
KEDA Pod Scale-out 검증

        ↓

Phase 4
Karpenter Node Scale-out 검증

        ↓

Phase 5
Scale-in / Consolidation 검증

        ↓

Phase 6
Pod 장애 주입

        ↓

Phase 7
Node 장애 주입

        ↓

Phase 8
RTO 측정

        ↓

Phase 9
SLO / Error Budget / Burn Rate 계산

        ↓

Phase 10
최종 결과 정리
```

DB 연결 장애, CrashLoopBackOff, HPA `<unknown>` 등 Baseline 자체가 비정상인 경우 테스트를 중단하고 원인을 먼저 해결합니다.

---

# 19. 테스트 전 최종 체크리스트

```text
[ ] kubectl cluster 접근 정상
[ ] 모든 대상 Deployment Ready
[ ] CrashLoopBackOff 없음
[ ] KEDA ScaledObject Ready
[ ] KEDA Pause 없음
[ ] HPA Metric 정상
[ ] kubectl top 정상
[ ] Prometheus 접근 정상
[ ] DB 연결 정상
[ ] 테스트 URL 확정
[ ] k6 접근 확인
[ ] 부하 강도 확인
[ ] results 디렉터리 확인
```

모든 항목이 정상인 상태에서 테스트를 시작합니다.

---

# 20. 주의사항

본 테스트 스크립트에는 실제 리소스 상태를 변경하는 장애 주입 작업이 포함되어 있습니다.

특히 다음 작업은 실행 전 대상 리소스를 반드시 확인합니다.

```text
Pod Delete
Node Cordon
Node Drain
CPU Stress
```

또한 AutoScaling 테스트 중에는 ArgoCD, KEDA, Karpenter 등 자동화 Controller가 동시에 리소스를 변경할 수 있으므로 Kubernetes Event와 Timeline을 함께 기록하여 결과를 분석합니다.

테스트 결과는 단순히 "Pod가 증가했다"가 아니라 다음 인과관계를 기준으로 판단합니다.

```text
부하 발생
→ Metric 증가
→ HPA Desired Replica 변화
→ Pod Scale-out
→ Scheduling Resource 부족
→ Karpenter Node Provisioning
→ Pod Scheduling
→ 서비스 정상 유지

부하 종료
→ Metric 감소
→ HPA Stabilization
→ Pod Scale-in
→ Node Underutilized
→ Karpenter Consolidation
```

이 전체 흐름이 확인되어야 AutoScaling 검증 완료로 판단합니다.

## 20.1 결과 해석 시 주의

- **DB 경로 병목**: 모든 백엔드가 tailscale-proxy Pod 1개(스팟 t3.small) → Tailscale(중계 DERP일 수 있음) → VM1 → CNPG → VM2 를 거칩니다. Pod가 많이 늘어나는 구간에서 `watch-db.sh`에 `Read timed out`, `connection attempt failed`가 나오면 DB 자체보다 이 경로의 한계일 가능성이 큽니다. VM에서 `tailscale ping <tailscale-proxy IP>`로 direct/DERP 여부를 먼저 확인합니다.
- **HPA `<unknown>`**: KEDA 트리거가 VM1 Prometheus를 조회하므로, VM 연결이 끊기면 `health-check.sh`가 실패합니다. 앱이 아니라 VM 연결 문제입니다.
- **Cloudflare 경유 부하**: k6가 Cloudflare를 거치면 봇 차단·요청 제한으로 403/429가 나올 수 있습니다. 실패율은 상태 코드별로 나눠 확인하고, Cloudflare 응답을 앱 장애로 집계하지 않습니다.