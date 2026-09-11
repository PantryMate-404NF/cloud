# GitOps 레포 구조

Argo CD가 바라볼 별도 레포지토리(예: `pantry-mate-gitops`)의 권장 구조입니다.

## 디렉토리 구조

```
pantry-mate-gitops/
├── environments/
│   ├── dev/
│   │   ├── pantry-mate-frontend/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── pantry-mate-backend/
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   └── prod/
│       ├── pantry-mate-frontend/
│       └── pantry-mate-backend/
```

## 매니페스트 예시

### environments/dev/pantry-mate-frontend/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pantry-mate-frontend
  namespace: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pantry-mate-frontend
  template:
    metadata:
      labels:
        app: pantry-mate-frontend
    spec:
      nodeSelector:
        role: worker
      containers:
        - name: frontend
          # Jenkins가 이 줄의 태그를 커밋SHA로 교체합니다
          image: <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/pantry-mate-dev-frontend:latest
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
```

### environments/dev/pantry-mate-frontend/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pantry-mate-frontend
  namespace: app
spec:
  selector:
    app: pantry-mate-frontend
  ports:
    - port: 3000
      targetPort: 3000
  type: ClusterIP
```

### environments/dev/pantry-mate-backend/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pantry-mate-backend
  namespace: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pantry-mate-backend
  template:
    metadata:
      labels:
        app: pantry-mate-backend
    spec:
      nodeSelector:
        role: worker
      containers:
        - name: backend
          # Jenkins가 이 줄의 태그를 커밋SHA로 교체합니다
          image: <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/pantry-mate-dev-backend:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
```

## Jenkins → GitOps 레포 업데이트 흐름

```
Jenkins 빌드 완료
    │
    │  ECR push: pantry-mate-dev-frontend:a1b2c3d4
    │
    ▼
GitOps 레포 clone
    │
    │  sed로 deployment.yaml 이미지 태그 교체
    │  image: ...frontend:latest → image: ...frontend:a1b2c3d4
    │
    ▼
git commit & push → main 브랜치
    │
    ▼
Argo CD 감지 (polling 1분 주기)
    │
    ▼
kubectl apply → EKS rolling update
```

## 주의사항

- `[skip ci]` 커밋 메시지를 사용해 GitOps 레포에서 Jenkins 재트리거를 방지합니다.
- `<AWS_ACCOUNT_ID>`는 실제 AWS 계정 ID로 교체하세요.
- `<ORG>`는 GitHub 조직명으로 교체하세요.
