import http from 'k6/http';
import { check, sleep } from 'k6';

/**
 * Bounded smoke benchmark for a public Finsights health endpoint.
 *
 * This script checks availability and response time across nodes.
 * It checks availability and response time only; it does not mutate application data.
 */
const baseUrl = (__ENV.FINSIGHTS_BASE_URL || __ENV.ROOMIFY_BASE_URL || '').replace(/\/$/, '');
const healthPath = __ENV.FINSIGHTS_HEALTH_PATH || __ENV.ROOMIFY_HEALTH_PATH || '/healthz';
const virtualUsers = Number(__ENV.FINSIGHTS_BENCHMARK_VUS || __ENV.ROOMIFY_BENCHMARK_VUS || '5');
const duration = __ENV.FINSIGHTS_BENCHMARK_DURATION || __ENV.ROOMIFY_BENCHMARK_DURATION || '60s';

export const options = {
  vus: virtualUsers,
  duration,
};

export default function () {
  const response = http.get(`${baseUrl}${healthPath}`, {
    tags: { name: 'finsights-health' },
    timeout: '10s',
  });

  check(response, {
    'health endpoint returns HTTP 2xx': (result) => result.status >= 200 && result.status < 300,
  });

  sleep(1);
}
