import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

const names = [
  'FRONTEND',
  'GATEWAY',
  'USER',
  'PRODUCT',
  'ORDER_PAYMENT',
  'PANTRY_RECIPE',
  'NOTIFICATION'
];

const scenarios = {};

// 서비스당 최대 VU (기본 20). 단계별 목표는 기본 곡선(5→10→15→20)을 이 값에 맞춰 비율로 조정한다
const MAX_VUS = Number(__ENV.MAX_VUS || 20);

if (!Number.isInteger(MAX_VUS) || MAX_VUS < 1 || MAX_VUS > 500) {
  throw new Error('MAX_VUS must be an integer 1..500');
}

// 요청 사이 대기(초). 0이면 쉬지 않고 연속 요청 (기본 1)
const SLEEP = Number(__ENV.SLEEP || 1);

if (!Number.isFinite(SLEEP) || SLEEP < 0 || SLEEP > 10) {
  throw new Error('SLEEP must be a number 0..10');
}

// 최대 VU 유지 시간. 스케일아웃·노드 추가까지 보려면 길게 (기본 2m)
const HOLD = __ENV.HOLD || '2m';

if (!/^\d+[smh]$/.test(HOLD)) {
  throw new Error('HOLD must look like 30s, 5m, 1h');
}

// ramp: 단계적 증가 / spike: 30초 만에 최대 VU로 급증 / soak: 최대의 절반으로 오래 유지
const PROFILE = __ENV.PROFILE || 'ramp';

const vus = (base) => Math.max(1, Math.round((base * MAX_VUS) / 20));

const profiles = {
  ramp: [
    { duration: '1m', target: vus(5)  },
    { duration: '2m', target: vus(10) },
    { duration: '2m', target: vus(15) },
    { duration: '2m', target: vus(20) },
    { duration: HOLD, target: vus(20) },
    { duration: '1m', target: 0  },
  ],
  spike: [
    { duration: '30s', target: vus(20) },
    { duration: HOLD,  target: vus(20) },
    { duration: '30s', target: 0 },
  ],
  soak: [
    { duration: '2m', target: vus(10) },
    { duration: HOLD, target: vus(10) },
    { duration: '1m', target: 0 },
  ],
};

if (!profiles[PROFILE]) {
  throw new Error(`PROFILE must be one of ${Object.keys(profiles).join(', ')}`);
}

// 서버 장애(5xx·타임아웃)와 Cloudflare 차단(429·403)을 구분하려고 응답 코드를 나눠 센다
const status5xx = new Counter('status_5xx');
const status429 = new Counter('status_429');
const status403 = new Counter('status_403');
const status4xx = new Counter('status_other_4xx');
const statusTimeout = new Counter('status_timeout');

const thresholds = {
  http_req_failed: ['rate<0.05'],
  http_req_duration: ['p(95)<1000'],
};

for (const name of names) {

  const url = __ENV[`${name}_URL`];

  if (!url) {
    continue;
  }

  const service = name.toLowerCase();

  scenarios[service] = {
    executor: 'ramping-vus',
    exec: 'request',

    stages: profiles[PROFILE],

    gracefulRampDown: '30s',

    env: {
      TARGET_URL: url,
      SERVICE: service,
    },

    tags: {
      service,
    },
  };

  // 서비스별 p95·실패율이 요약에 나오도록 서비스 태그 기준 임계값을 둔다
  thresholds[`http_req_duration{service:${service}}`] = ['p(95)<1000'];
  thresholds[`http_req_failed{service:${service}}`] = ['rate<0.05'];
}

if (Object.keys(scenarios).length === 0) {
  throw new Error('Configure at least one *_URL');
}

export const options = {
  scenarios,
  thresholds,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

export function request() {

  const tags = { service: __ENV.SERVICE };

  const response = http.get(
    __ENV.TARGET_URL,
    {
      timeout: '10s',
      tags,
    }
  );

  if (response.status === 0) statusTimeout.add(1, tags);
  else if (response.status === 429) status429.add(1, tags);
  else if (response.status === 403) status403.add(1, tags);
  else if (response.status >= 500) status5xx.add(1, tags);
  else if (response.status >= 400) status4xx.add(1, tags);

  check(
    response,
    {
      'HTTP 2xx': (r) =>
        r.status >= 200 && r.status < 300,
    },
    tags
  );

  if (SLEEP > 0) {
    sleep(SLEEP);
  }
}

export function handleSummary(data) {

  const dir = __ENV.RESULT_DIR || '.';

  const m = data.metrics;
  const count = (key) => (m[key] ? m[key].values.count : 0);
  const ms = (v) => `${Math.round(v)}ms`;
  const pct = (v) => `${(v * 100).toFixed(2)}%`;
  const d = m.http_req_duration.values;

  const lines = [
    '',
    '===== LOAD SUMMARY =====',
    `profile=${PROFILE} max_vus_per_service=${MAX_VUS} sleep=${SLEEP}s hold=${HOLD}`,
    `requests=${m.http_reqs.values.count} rps=${m.http_reqs.values.rate.toFixed(1)}`,
    `failed=${pct(m.http_req_failed.values.rate)} p95=${ms(d['p(95)'])} p99=${ms(d['p(99)'])} max=${ms(d.max)}`,
    `5xx=${count('status_5xx')} timeout=${count('status_timeout')} ` +
      `429=${count('status_429')} 403=${count('status_403')} other4xx=${count('status_other_4xx')}`,
    '',
    'per service:',
  ];

  for (const key of Object.keys(m)) {
    const found = key.match(/^http_req_duration\{service:(.+)\}$/);
    if (!found) continue;
    const fail = m[`http_req_failed{service:${found[1]}}`];
    lines.push(
      `  ${found[1].padEnd(14)} p95=${ms(m[key].values['p(95)'])} ` +
      `failed=${fail ? pct(fail.values.rate) : '?'}`
    );
  }

  if (count('status_429') + count('status_403') > 0) {
    lines.push('');
    lines.push('NOTE: 429/403 은 Cloudflare 차단일 가능성이 큼. 서버 장애(5xx·timeout)와 구분해서 볼 것');
  }

  lines.push('');

  return {
    stdout: lines.join('\n'),
    [`${dir}/k6-summary.json`]:
      JSON.stringify(data, null, 2),
  };
}
