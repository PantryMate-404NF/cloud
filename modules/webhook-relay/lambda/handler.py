"""
GitHub → API Gateway → Lambda → Jenkins 내부 NLB 웹훅 릴레이

Lambda는 VPC 내부에 배치되어 Jenkins 내부 NLB에 직접 접근합니다.
GitHub 웹훅 페이로드의 HMAC-SHA256 서명을 검증한 뒤 Jenkins /github-webhook/ 로 전달합니다.
"""

import hashlib
import hmac
import json
import os
import urllib.error
import urllib.request


def _get_webhook_secret() -> str:
    """SSM Parameter Store에서 GitHub webhook secret을 가져옵니다."""
    import boto3

    ssm = boto3.client("ssm", region_name=os.environ["AWS_REGION"])
    response = ssm.get_parameter(
        Name=os.environ["GITHUB_WEBHOOK_SECRET_PARAM"],
        WithDecryption=True,
    )
    return response["Parameter"]["Value"]


# Lambda 컨테이너 재사용 시 SSM 호출을 줄이기 위해 모듈 수준에서 캐시합니다.
_cached_secret: str | None = None


def _webhook_secret() -> str:
    global _cached_secret
    if _cached_secret is None:
        _cached_secret = _get_webhook_secret()
    return _cached_secret


def _verify_signature(payload: bytes, signature_header: str) -> bool:
    """X-Hub-Signature-256 헤더의 HMAC-SHA256 서명을 검증합니다."""
    if not signature_header or not signature_header.startswith("sha256="):
        return False

    expected = "sha256=" + hmac.new(
        _webhook_secret().encode("utf-8"),
        payload,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected, signature_header)


def handler(event: dict, context) -> dict:
    # ── 요청 바디 ─────────────────────────────────────────────────────────
    body_str: str = event.get("body") or ""
    is_base64: bool = event.get("isBase64Encoded", False)

    if is_base64:
        import base64
        payload = base64.b64decode(body_str)
    else:
        payload = body_str.encode("utf-8")

    # ── 헤더 정규화 ───────────────────────────────────────────────────────
    raw_headers: dict = event.get("headers") or {}
    headers = {k.lower(): v for k, v in raw_headers.items()}

    # ── 서명 검증 ─────────────────────────────────────────────────────────
    signature = headers.get("x-hub-signature-256", "")
    if not _verify_signature(payload, signature):
        print("ERROR: Invalid webhook signature")
        return {"statusCode": 403, "body": json.dumps({"error": "Forbidden"})}

    # ── Jenkins로 포워딩 ──────────────────────────────────────────────────
    jenkins_url = os.environ["JENKINS_URL"].rstrip("/")
    target = f"{jenkins_url}/github-webhook/"

    forward_headers = {
        "Content-Type": headers.get("content-type", "application/json"),
        "X-GitHub-Event": headers.get("x-github-event", ""),
        "X-GitHub-Delivery": headers.get("x-github-delivery", ""),
        "X-Hub-Signature-256": signature,
    }

    req = urllib.request.Request(
        url=target,
        data=payload,
        headers={k: v for k, v in forward_headers.items() if v},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            print(f"INFO: Forwarded to Jenkins — HTTP {resp.status}")
            return {"statusCode": 200, "body": json.dumps({"result": "forwarded"})}
    except urllib.error.HTTPError as exc:
        print(f"ERROR: Jenkins returned HTTP {exc.code}")
        return {"statusCode": exc.code, "body": json.dumps({"error": str(exc)})}
    except Exception as exc:
        print(f"ERROR: Failed to reach Jenkins — {exc}")
        return {"statusCode": 502, "body": json.dumps({"error": "Bad Gateway"})}
