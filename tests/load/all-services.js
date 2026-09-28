import http from 'k6/http';
import { check, sleep } from 'k6';

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

for (const name of names) {

  const url = __ENV[`${name}_URL`];

  if (!url) {
    continue;
  }

  scenarios[name.toLowerCase()] = {
    executor: 'ramping-vus',
    exec: 'request',

    stages: [
      { duration: '1m', target: 5  },
      { duration: '2m', target: 10 },
      { duration: '2m', target: 15 },
      { duration: '2m', target: 20 },
      { duration: '2m', target: 20 },
      { duration: '1m', target: 0  },
    ],

    gracefulRampDown: '30s',

    env: {
      TARGET_URL: url,
      SERVICE: name.toLowerCase(),
    },

    tags: {
      service: name.toLowerCase(),
    },
  };
}

if (Object.keys(scenarios).length === 0) {
  throw new Error('Configure at least one *_URL');
}

export const options = {
  scenarios,

  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1000'],
  },
};

export function request() {

  const response = http.get(
    __ENV.TARGET_URL,
    {
      timeout: '10s',
      tags: {
        service: __ENV.SERVICE,
      },
    }
  );

  check(
    response,
    {
      'HTTP 2xx': (r) =>
        r.status >= 200 && r.status < 300,
    },
    {
      service: __ENV.SERVICE,
    }
  );

  sleep(1);
}

export function handleSummary(data) {

  const dir = __ENV.RESULT_DIR || '.';

  return {
    [`${dir}/k6-summary.json`]:
      JSON.stringify(data, null, 2),
  };
}
