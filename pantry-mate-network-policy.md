# pantry-mate Kubernetes Network Policy 정리

## 레이어 구조

Network Policy는 Security Group과 레이어가 다르며, 둘 다 적용해야 합니다.

```
외부 트래픽
    ↓
[AWS Security Group] ← 노드/ENI 레벨, VPC 경계
    ↓
[Kubernetes Network Policy] ← Pod 레벨, 클러스터 내부
    ↓
Pod
```

SG 규칙은 그대로 유지하고, Network Policy를 추가로 적용하는 구조입니다.

> **전제**: Network Policy를 지원하는 CNI 필요
> AWS VPC CNI v1.14+는 기본 지원, 또는 Calico/Cilium 사용

---

## 기본 원칙: Default Deny 후 필요한 것만 허용

각 네임스페이스에 먼저 default deny를 적용합니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## 네임스페이스별 허용 규칙

### jenkins 네임스페이스

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | 노드 CIDR (10.0.0.0/16) | TCP 8080 | Lambda → NLB → Jenkins webhook |
| IN | 동일 네임스페이스 | ALL | Jenkins agent 통신 |
| OUT | 0.0.0.0/0 | TCP 443 | ECR, S3, GitHub API, AWS API |
| OUT | kube-system | TCP 443 | kube-apiserver |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: jenkins-policy
  namespace: jenkins
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 10.0.0.0/16
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - podSelector: {}   # 동일 네임스페이스
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 443
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: TCP
      port: 443
```

---

### app 네임스페이스 (frontend / backend)

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | cloudflare 네임스페이스 | TCP 3000/8080 | cloudflared → 앱 |
| IN | monitoring 네임스페이스 | ALL | OTel scrape (pull 방식인 경우) |
| OUT | tailscale 네임스페이스 | ALL | DB/외부 통신 (Tailscale 경유) |
| OUT | 0.0.0.0/0 | TCP 443 | 외부 API 호출 |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-policy
  namespace: app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: cloudflare
    ports:
    - protocol: TCP
      port: 3000   # frontend
    - protocol: TCP
      port: 8080   # backend
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: tailscale
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 443
```

---

### cloudflare 네임스페이스

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | 없음 | — | 외부 인바운드 없음 |
| OUT | app 네임스페이스 | TCP 3000/8080 | 앱으로 트래픽 전달 |
| OUT | 0.0.0.0/0 | TCP 7844, UDP 7844 | Cloudflare edge 터널 |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cloudflare-policy
  namespace: cloudflare
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []   # 인바운드 없음
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: app
    ports:
    - protocol: TCP
      port: 3000
    - protocol: TCP
      port: 8080
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 7844
    - protocol: UDP
      port: 7844
```

---

### monitoring 네임스페이스 (OTel Collector)

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | app 네임스페이스 | TCP 4317, 4318 | 앱 → OTel (push 방식) |
| OUT | tailscale 네임스페이스 | ALL | 온프레미스 PLG로 전송 |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: app
    ports:
    - protocol: TCP
      port: 4317   # gRPC
    - protocol: TCP
      port: 4318   # HTTP
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: tailscale
```

---

### tailscale 네임스페이스

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | app, monitoring 네임스페이스 | ALL | 터널 진입 트래픽 |
| OUT | 0.0.0.0/0 | UDP 41641, TCP 443 | Tailscale 연결 |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tailscale-policy
  namespace: tailscale
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: app
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: UDP
      port: 41641
    - protocol: TCP
      port: 443
```

---

### argocd 네임스페이스

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| IN | 없음 (또는 관리자 IP) | — | UI는 Tailscale 경유 접근 |
| OUT | 0.0.0.0/0 | TCP 443 | GitOps 레포 pull |
| OUT | kube-system | TCP 443 | kube-apiserver |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-policy
  namespace: argocd
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 443
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: TCP
      port: 443
```

---

### keda / karpenter 네임스페이스

| 방향 | 대상 | 포트 | 용도 |
|------|------|------|------|
| OUT | kube-system | TCP 443 | kube-apiserver |
| OUT | 0.0.0.0/0 | TCP 443 | AWS API (SQS, EC2 등) |

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: keda-policy
  namespace: keda   # karpenter도 동일 구조
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: TCP
      port: 443
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 443
```

---

## SG vs Network Policy 역할 분담 요약

| 항목 | AWS Security Group | Network Policy |
|------|-------------------|---------------|
| 적용 레벨 | 노드/ENI | Pod |
| 제어 단위 | IP/포트 | Pod 셀렉터/네임스페이스 |
| VPC 외부 트래픽 | 제어 가능 | egress로 제어 가능 |
| 클러스터 내 Pod 간 | 제어 어려움 | 정밀 제어 가능 |
| 필수 여부 | 필수 | 보안 강화 시 추가 |

두 레이어를 모두 적용하면 **VPC 경계(SG) + Pod 간 최소 권한(Network Policy)** 이중 방어가 됩니다.

---

## 적용 순서 권장사항

1. CNI Network Policy 지원 확인 (VPC CNI v1.14+ 또는 Calico/Cilium 설치)
2. 네임스페이스에 `kubernetes.io/metadata.name` 레이블 확인 (K8s 1.21+는 자동 부여)
3. default-deny 적용 전 반드시 허용 정책 먼저 배포 → 순서 바꾸면 기존 트래픽 차단됨
4. `kubectl exec`로 Pod 간 통신 테스트 후 deny 적용
