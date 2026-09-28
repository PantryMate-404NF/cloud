#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path


# =====================================================================
# 1. 프로젝트 기본 SLO 정책
# =====================================================================

# Backend Availability 목표
#
# 성공 요청 비율이 99.9% 이상이어야 한다.
BACKEND_SLO = 99.9


# AI Latency 목표
#
# AI 요청 중 99% 이상이 3초 이내에 응답해야 한다.
AI_LATENCY_SLO = 99.0


# AI 요청을 Good Event로 판단하는 최대 응답시간
#
# k6는 응답시간을 ms 단위로 사용하므로
# 3초 = 3000ms 로 정의한다.
AI_LATENCY_THRESHOLD_MS = 3000.0


# 보고서에서 정의한 Burn Rate 기준
#
# 실제 운영에서는 각각 1시간 / 6시간 Rolling Window와
# 함께 사용해야 한다.
CRITICAL_BURN_RATE = 14.4
WARNING_BURN_RATE = 6.0


# =====================================================================
# 2. 공통 Utility 함수
# =====================================================================

def get_metric(metrics, name):

    metric = metrics.get(name)

    if not metric:
        return None

    return metric.get("values", {})


def safe_float(value, default=0.0):
    """
    JSON에서 읽은 값을 float로 변환한다.

    값이 없거나 숫자로 변환할 수 없는 경우에는
    default 값을 반환한다.
    """

    try:
        return float(value)

    except (TypeError, ValueError):
        return default


# =====================================================================
# 3. SLO / Error Budget / Burn Rate 핵심 계산
# =====================================================================

def calculate_slo(total, bad, target):
    # 요청 자체가 없다면 SLO를 계산할 수 없다.
    if total <= 0:

        return {
            "total": 0,
            "bad": 0,
            "good": 0,
            "availability": 0.0,
            "target": target,
            "error_budget_rate": 1 - target / 100,
            "allowed_bad": 0.0,
            "bad_rate": 0.0,
            "budget_consumed_percent": 0.0,
            "burn_rate": 0.0,
            "slo_met": False,
            "budget_exhausted": False,
        }

    # 정상 Event 수
    good = max(total - bad, 0)

    # 실제 실패/위반 비율
    bad_rate = bad / total

    # 실제 SLI (%)
    availability = (good / total) * 100

    # SLO에서 허용하는 Error Budget 비율
    error_budget_rate = 1 - (target / 100)

    # 현재 요청 수를 기준으로 허용되는 Bad Event 수
    allowed_bad = total * error_budget_rate

    # 실제 Bad Event Rate가 Error Budget의 몇 배인지 계산
    if error_budget_rate > 0:

        burn_rate = bad_rate / error_budget_rate

    else:

        # SLO가 100%인 경우 Error Budget이 0이므로
        # Burn Rate를 정상적으로 나눌 수 없다.
        burn_rate = float("inf")

    # Error Budget을 몇 % 사용했는지 계산
    if allowed_bad > 0:

        budget_consumed_percent = (
            bad / allowed_bad
        ) * 100

    else:

        budget_consumed_percent = float("inf")

    return {
        "total": total,
        "bad": bad,
        "good": good,

        # 실제 SLI
        "availability": availability,

        # 목표 SLO
        "target": target,

        # 허용 실패 비율
        "error_budget_rate": error_budget_rate,

        # 허용 실패 건수
        "allowed_bad": allowed_bad,

        # 실제 실패 비율
        "bad_rate": bad_rate,

        # Error Budget 소진율
        "budget_consumed_percent": budget_consumed_percent,

        # Burn Rate
        "burn_rate": burn_rate,

        # 실제 SLI가 SLO 이상인지 여부
        "slo_met": availability >= target,

        # 실제 Bad Event가 허용량을 초과했는지 여부
        "budget_exhausted": bad > allowed_bad,
    }


# =====================================================================
# 4. Burn Rate 상태 분류
# =====================================================================

def burn_level(burn_rate):
    """
    Burn Rate 값을 사람이 보기 쉬운 상태로 변환한다.

    보고서 기준:

        Critical = 14.4x 초과
        Warning  = 6.0x 초과

    추가로 1.0x를 초과하면 Error Budget을 목표보다 빠른 속도로
    소진하고 있다는 의미이므로 BUDGET BURNING FAST로 표시한다.


    주의
    ----

    실제 운영 경보의 의미는 다음과 같다.

        Critical:
            최근 1시간 Burn Rate > 14.4

        Warning:
            최근 6시간 Burn Rate > 6.0

    하지만 k6 summary는 해당 Rolling Window를 제공하지 않는다.

    따라서 여기에서 출력되는 CRITICAL / WARNING은
    "이번 테스트 구간의 Burn Rate를 동일 임계값과 비교한 참고값"이다.
    """

    if burn_rate > CRITICAL_BURN_RATE:
        return "CRITICAL"

    if burn_rate > WARNING_BURN_RATE:
        return "WARNING"

    if burn_rate > 1.0:
        return "BUDGET BURNING FAST"

    return "NORMAL"


# =====================================================================
# 5. 결과 출력
# =====================================================================

def print_slo(title, result):
    """
    calculate_slo()에서 계산한 결과를 사람이 읽기 쉬운 형태로 출력한다.
    """

    print()
    print("=" * 72)
    print(title)
    print("=" * 72)

    print(f"Total Events            : {result['total']}")
    print(f"Good Events             : {result['good']}")
    print(f"Bad Events              : {result['bad']}")

    print()

    print(
        f"SLI                     : "
        f"{result['availability']:.4f}%"
    )

    print(
        f"SLO Target              : "
        f"{result['target']:.4f}%"
    )

    print()

    print(
        f"Error Budget            : "
        f"{result['error_budget_rate'] * 100:.4f}%"
    )

    print(
        f"Allowed Bad Events      : "
        f"{result['allowed_bad']:.2f}"
    )

    print(
        f"Actual Bad Event Rate   : "
        f"{result['bad_rate'] * 100:.4f}%"
    )

    print()

    print(
        f"Error Budget Consumed   : "
        f"{result['budget_consumed_percent']:.2f}%"
    )

    print(
        f"Burn Rate               : "
        f"{result['burn_rate']:.2f}x"
    )

    print(
        f"Burn Status             : "
        f"{burn_level(result['burn_rate'])}"
    )

    print()

    print(
        f"SLO Result              : "
        f"{'PASS' if result['slo_met'] else 'FAIL'}"
    )

    print(
        f"Error Budget Result     : "
        f"{'EXHAUSTED' if result['budget_exhausted'] else 'WITHIN BUDGET'}"
    )


# =====================================================================
# 6. Backend Availability 계산
# =====================================================================

def calculate_backend(metrics, target):


    reqs = get_metric(
        metrics,
        "http_reqs",
    )

    failed = get_metric(
        metrics,
        "http_req_failed",
    )

    # 필수 metric이 없다면 계산 불가
    if not reqs or not failed:
        return None

    # 전체 요청 수
    total = int(
        safe_float(
            reqs.get("count")
        )
    )

    # k6가 계산한 전체 요청 실패율
    failure_rate = safe_float(
        failed.get("rate")
    )

    # 실패율로부터 실패 건수를 추정
    bad = round(
        total * failure_rate
    )

    return calculate_slo(
        total=total,
        bad=bad,
        target=target,
    )


# =====================================================================
# 7. AI Latency SLO 계산
# =====================================================================

def calculate_ai_latency(
    metrics,
    target,
    threshold_ms,
):


    reqs = get_metric(
        metrics,
        "ai_requests",
    )

    good_metric = get_metric(
        metrics,
        "ai_latency_good",
    )

    # AI custom metric이 모두 존재한다면 정확한 계산 가능
    if reqs and good_metric:

        total = int(
            safe_float(
                reqs.get("count")
            )
        )

        good = int(
            safe_float(
                good_metric.get("count")
            )
        )

        bad = max(
            total - good,
            0,
        )

        result = calculate_slo(
            total=total,
            bad=bad,
            target=target,
        )

        # 정확한 custom metric으로 계산했다는 표시
        result["exact"] = True

        return result

    # AI custom metric이 없다면 전체 HTTP P95라도 확인한다.
    duration = get_metric(
        metrics,
        "http_req_duration",
    )

    if not duration:
        return None

    p95 = safe_float(
        duration.get("p(95)"),
        -1,
    )

    return {
        "exact": False,
        "p95_ms": p95,
        "threshold_ms": threshold_ms,
    }


def print_ai_latency(result):
    """
    AI Latency 계산 결과를 출력한다.

    AI custom metric이 없는 경우에는 SLO PASS/FAIL을 임의로
    판단하지 않고 "정확한 계산 불가"라고 명시한다.
    """

    print()
    print("=" * 72)
    print("AI SERVING LATENCY SLO")
    print("=" * 72)

    if result is None:

        print("AI latency metrics not found.")

        return

    # custom metric이 없어서 정확한 AI SLO를 계산할 수 없는 경우
    if result.get("exact") is False:

        print(
            "Exact AI latency SLI cannot be calculated "
            "from the current k6 summary."
        )

        print()

        if result["p95_ms"] >= 0:

            print(
                f"Overall HTTP P95         : "
                f"{result['p95_ms']:.2f} ms"
            )

        print(
            f"AI Good Event Condition : "
            f"response <= {result['threshold_ms']:.0f} ms"
        )

        print()

        print(
            "Required k6 Metrics     : "
            "ai_requests + ai_latency_good"
        )

        print()

        print(
            "Reason:"
        )

        print(
            "P95 alone cannot determine the exact percentage "
            "of AI requests completed within 3 seconds."
        )

        return

    # custom metric이 있다면 일반 SLO 출력 형식 사용
    print_slo(
        "AI LATENCY SLO (response <= 3.0 sec)",
        result,
    )


# =====================================================================
# 8. 보고서 정책 출력
# =====================================================================

def print_report_policy():
    """
    현재 스크립트가 어떤 SLO 정책을 기준으로 계산했는지 출력한다.

    결과 파일만 전달받은 사람도 계산 기준을 확인할 수 있도록
    결과에 정책을 함께 남긴다.
    """

    print()
    print("=" * 72)
    print("SLO / ERROR BUDGET POLICY")
    print("=" * 72)

    print(
        "Backend Availability SLO : "
        "99.9%"
    )

    print(
        "Backend Error Budget      : "
        "0.1%"
    )

    print()

    print(
        "AI Latency SLO            : "
        "99.0%"
    )

    print(
        "AI Good Event             : "
        "response <= 3.0 sec"
    )

    print(
        "AI Error Budget           : "
        "1.0%"
    )

    print()

    print(
        "Critical Burn Policy      : "
        "1h Burn Rate > 14.4"
    )

    print(
        "Warning Burn Policy       : "
        "6h Burn Rate > 6.0"
    )

    print()

    print(
        "IMPORTANT:"
    )

    print(
        "The 1h/6h policies require Prometheus "
        "rolling-window metrics."
    )


# =====================================================================
# 9. 운영 환경 Prometheus 쿼리 출력
# =====================================================================

def print_prometheus_queries():


    print()
    print("=" * 72)
    print("PROMETHEUS / PRODUCTION SLO QUERIES")
    print("=" * 72)

    print(
        r"""
----------------------------------------------------------------------
[1] Backend Availability - 최근 30일
----------------------------------------------------------------------

(
  sum(
    rate(
      http_server_requests_seconds_count{
        status!~"5..",
        uri!~"/actuator.*"
      }[30d]
    )
  )
  /
  sum(
    rate(
      http_server_requests_seconds_count{
        uri!~"/actuator.*"
      }[30d]
    )
  )
) * 100


----------------------------------------------------------------------
[2] Backend Critical Burn Rate - 최근 1시간
----------------------------------------------------------------------

(
  sum(
    rate(
      http_server_requests_seconds_count{
        status=~"5..",
        uri!~"/actuator.*"
      }[1h]
    )
  )
  /
  sum(
    rate(
      http_server_requests_seconds_count{
        uri!~"/actuator.*"
      }[1h]
    )
  )
) / 0.001


판정 기준:

    Burn Rate > 14.4

주의:

    0.001은 Backend SLO 99.9%의 Error Budget인 0.1%를
    소수로 표현한 값이다.


----------------------------------------------------------------------
[3] AI Latency SLI - 최근 30일
----------------------------------------------------------------------

(
  sum(
    rate(
      http_request_duration_seconds_bucket{
        le="3.0",
        path=~"/predict|/recommend.*"
      }[30d]
    )
  )
  /
  sum(
    rate(
      http_request_duration_seconds_count{
        path=~"/predict|/recommend.*"
      }[30d]
    )
  )
) * 100


의미:

    최근 30일 동안 발생한 AI 요청 중
    3초 이내에 완료된 요청의 비율


----------------------------------------------------------------------
[4] AI Warning Burn Rate - 최근 6시간
----------------------------------------------------------------------

(
  (
    sum(
      rate(
        http_request_duration_seconds_count{
          path=~"/predict|/recommend.*"
        }[6h]
      )
    )
    -
    sum(
      rate(
        http_request_duration_seconds_bucket{
          le="3.0",
          path=~"/predict|/recommend.*"
        }[6h]
      )
    )
  )
  /
  sum(
    rate(
      http_request_duration_seconds_count{
        path=~"/predict|/recommend.*"
      }[6h]
    )
  )
) / 0.01


판정 기준:

    Burn Rate > 6.0

주의:

    0.01은 AI SLO 99.0%의 Error Budget인 1.0%를
    소수로 표현한 값이다.
"""
    )


# =====================================================================
# 10. Main
# =====================================================================

def main():
    """
    프로그램 실행 진입점.

    기본 사용법:

        python3 slo/calculate-slo.py \
          results/<TEST_ID>/k6-summary.json


    PromQL까지 같이 확인:

        python3 slo/calculate-slo.py \
          results/<TEST_ID>/k6-summary.json \
          --show-promql


    SLO 값을 임시로 변경해야 할 경우:

        python3 slo/calculate-slo.py \
          results/<TEST_ID>/k6-summary.json \
          --backend-target 99.9 \
          --ai-target 99.0
    """

    parser = argparse.ArgumentParser(
        description=(
            "Pantry-Mate k6 Test-Window "
            "SLO / Error Budget / Burn Rate Calculator"
        )
    )

    # k6가 생성한 summary JSON 경로
    parser.add_argument(
        "summary",
        help="Path to k6-summary.json",
    )

    # Backend SLO.
    # 옵션을 생략하면 프로젝트 정책인 99.9% 사용.
    parser.add_argument(
        "--backend-target",
        type=float,
        default=BACKEND_SLO,
        help=(
            "Backend availability SLO percentage "
            "(default: 99.9)"
        ),
    )

    # AI SLO.
    # 옵션을 생략하면 프로젝트 정책인 99.0% 사용.
    parser.add_argument(
        "--ai-target",
        type=float,
        default=AI_LATENCY_SLO,
        help=(
            "AI latency SLO percentage "
            "(default: 99.0)"
        ),
    )

    # 보고서의 PromQL을 함께 출력할지 결정
    parser.add_argument(
        "--show-promql",
        action="store_true",
        help=(
            "Print Prometheus 30d/1h/6h "
            "production SLO queries"
        ),
    )

    args = parser.parse_args()

    # 잘못된 SLO 입력 방지
    if not 0 < args.backend_target < 100:

        parser.error(
            "backend target must be between 0 and 100"
        )

    if not 0 < args.ai_target < 100:

        parser.error(
            "AI target must be between 0 and 100"
        )

    # 입력 파일 존재 여부 확인
    path = Path(
        args.summary
    )

    if not path.exists():

        print(
            f"ERROR: summary file not found: {path}",
            file=sys.stderr,
        )

        return 2

    # k6 summary JSON 읽기
    try:

        with path.open(
            encoding="utf-8"
        ) as f:

            data = json.load(f)

    except (
        OSError,
        json.JSONDecodeError,
    ) as e:

        print(
            f"ERROR: unable to read summary: {e}",
            file=sys.stderr,
        )

        return 2

    # k6 summary의 실제 metric 영역
    metrics = data.get(
        "metrics",
        {},
    )

    print()
    print("#" * 72)
    print(
        "# PANTRY-MATE SLO / ERROR BUDGET / BURN RATE REPORT"
    )
    print("#" * 72)

    print()
    print(
        f"Input Summary           : {path}"
    )

    # -------------------------------------------------------------
    # Backend Availability 계산
    # -------------------------------------------------------------

    backend = calculate_backend(
        metrics,
        args.backend_target,
    )

    if backend is None:

        print()
        print(
            "ERROR: Required metrics "
            "http_reqs/http_req_failed were not found."
        )

        return 2

    print_slo(
        "BACKEND / TEST-WINDOW AVAILABILITY SLO",
        backend,
    )

    # -------------------------------------------------------------
    # AI Latency 계산
    # -------------------------------------------------------------

    ai = calculate_ai_latency(
        metrics,
        args.ai_target,
        AI_LATENCY_THRESHOLD_MS,
    )

    print_ai_latency(
        ai
    )

    # -------------------------------------------------------------
    # 사용한 정책 출력
    # -------------------------------------------------------------

    print_report_policy()

    # 요청한 경우 운영 PromQL도 출력
    if args.show_promql:

        print_prometheus_queries()

    # -------------------------------------------------------------
    # 최종 해석 주의사항
    # -------------------------------------------------------------

    print()
    print("=" * 72)
    print("INTERPRETATION / IMPORTANT NOTES")
    print("=" * 72)

    print(
        "1. This result is calculated from the k6 TEST WINDOW."
    )

    print(
        "2. It is NOT the actual 30-day rolling production SLO."
    )

    print(
        "3. Actual 30d SLO must be calculated from Prometheus."
    )

    print(
        "4. Actual Critical alert requires 1h Burn Rate > 14.4."
    )

    print(
        "5. Actual Warning alert requires 6h Burn Rate > 6.0."
    )

    print(
        "6. AI 99% <= 3s SLO requires AI-specific custom metrics."
    )

    print()

    # Backend SLO 결과를 프로그램 종료 코드에도 반영한다.
    #
    # PASS -> exit 0
    # FAIL -> exit 1
    #
    # 따라서 향후 자동화 스크립트에서도 성공/실패 판정에 사용할 수 있다.
    if backend["slo_met"]:

        print(
            "FINAL BACKEND SLO RESULT : PASS"
        )

        return 0

    print(
        "FINAL BACKEND SLO RESULT : FAIL"
    )

    return 1


if __name__ == "__main__":
    sys.exit(
        main()
    )