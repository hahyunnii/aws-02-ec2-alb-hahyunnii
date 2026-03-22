#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT_DIR}/state.env"
BENCH_DIR="${ROOT_DIR}/benchmark"

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "state.env not found. Run scripts/deploy-ec2-alb.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "${STATE_FILE}"

REQUESTS="${REQUESTS:-200}"
CONCURRENCY="${CONCURRENCY:-20}"
TARGET_MODE="${TARGET_MODE:-all}" # all | alb | direct

mkdir -p "${BENCH_DIR}"
SUMMARY_FILE="${BENCH_DIR}/summary.csv"
echo "target,tool,requests,success,failed,avg_time_sec,p95_time_sec,requests_per_sec" > "${SUMMARY_FILE}"

run_ab() {
  local label="$1"
  local url="$2"
  local raw_file="${BENCH_DIR}/${label}.ab.txt"

  ab -n "${REQUESTS}" -c "${CONCURRENCY}" -q "${url}" > "${raw_file}" 2>&1 || true

  local rps failed avg_ms
  rps=$(awk -F': *' '/Requests per second/ {print $2}' "${raw_file}" | awk '{print $1}' | tail -n1)
  failed=$(awk -F': *' '/Failed requests/ {print $2}' "${raw_file}" | tail -n1)
  avg_ms=$(awk -F': *' '/Time per request/ {print $2}' "${raw_file}" | awk 'NR==1{print $1}')

  if [[ -z "${rps}" ]]; then rps="0"; fi
  if [[ -z "${failed}" ]]; then failed="0"; fi
  if [[ -z "${avg_ms}" ]]; then avg_ms="0"; fi

  local success avg_sec
  success=$((REQUESTS - failed))
  avg_sec=$(awk -v ms="${avg_ms}" 'BEGIN{printf "%.6f", ms/1000.0}')

  echo "${label},ab,${REQUESTS},${success},${failed},${avg_sec},n/a,${rps}" >> "${SUMMARY_FILE}"
  echo "[BENCH] ${label}: ab done (rps=${rps}, failed=${failed})"
}

run_curl_fallback() {
  local label="$1"
  local url="$2"
  local raw_file="${BENCH_DIR}/${label}.curl.txt"
  local start_ts end_ts elapsed

  : > "${raw_file}"
  start_ts=$(date +%s)

  for i in $(seq 1 "${REQUESTS}"); do
    curl -s -o /dev/null -w "%{http_code} %{time_total}\n" "${url}" >> "${raw_file}" &
    if (( i % CONCURRENCY == 0 )); then
      wait
    fi
  done
  wait
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  if (( elapsed <= 0 )); then
    elapsed=1
  fi

  local success failed avg_sec p95_sec rps
  success=$(awk '$1 ~ /^2/ {c++} END{print c+0}' "${raw_file}")
  failed=$((REQUESTS - success))
  avg_sec=$(awk '{sum+=$2; n++} END{if(n==0) print "0"; else printf "%.6f", sum/n}' "${raw_file}")
  p95_sec=$(awk '{print $2}' "${raw_file}" | sort -n | awk '{a[NR]=$1} END{if(NR==0){print "0"} else {idx=int(NR*0.95); if(idx<1) idx=1; printf "%.6f", a[idx]}}')
  rps=$(awk -v req="${REQUESTS}" -v sec="${elapsed}" 'BEGIN{if(sec==0) print "0"; else printf "%.2f", req/sec}')

  echo "${label},curl,${REQUESTS},${success},${failed},${avg_sec},${p95_sec},${rps}" >> "${SUMMARY_FILE}"
  echo "[BENCH] ${label}: curl fallback done (success=${success}, failed=${failed})"
}

run_benchmark() {
  local label="$1"
  local url="$2"

  echo "[TARGET] ${label} -> ${url}"
  for _ in $(seq 1 5); do curl -s -o /dev/null "${url}" || true; done

  if command -v ab >/dev/null 2>&1; then
    run_ab "${label}" "${url}"
  else
    run_curl_fallback "${label}" "${url}"
  fi
}

ALB_URL="http://${ALB_DNS}"

INSTANCE_INFO=$(aws ec2 describe-instances \
  --instance-ids "${INSTANCE_ID_1}" "${INSTANCE_ID_2}" \
  --region "${AWS_REGION}" \
  --query 'Reservations[].Instances[].{Id:InstanceId,PublicIp:PublicIpAddress}' \
  --output text)

IP1=$(echo "${INSTANCE_INFO}" | awk -v id="${INSTANCE_ID_1}" '$1==id{print $2}')
IP2=$(echo "${INSTANCE_INFO}" | awk -v id="${INSTANCE_ID_2}" '$1==id{print $2}')

echo "[INFO] Region: ${AWS_REGION}"
echo "[INFO] Requests=${REQUESTS}, Concurrency=${CONCURRENCY}, Mode=${TARGET_MODE}"
echo "[INFO] ALB=${ALB_URL}"
echo "[INFO] Direct instance IPs: ${IP1:-none}, ${IP2:-none}"

if [[ "${TARGET_MODE}" == "all" || "${TARGET_MODE}" == "alb" ]]; then
  run_benchmark "alb" "${ALB_URL}"
fi

if [[ "${TARGET_MODE}" == "all" || "${TARGET_MODE}" == "direct" ]]; then
  if [[ -n "${IP1:-}" && "${IP1}" != "None" ]]; then
    run_benchmark "direct-1" "http://${IP1}"
  else
    echo "[WARN] direct-1 skipped (no public IP)."
  fi

  if [[ -n "${IP2:-}" && "${IP2}" != "None" ]]; then
    run_benchmark "direct-2" "http://${IP2}"
  else
    echo "[WARN] direct-2 skipped (no public IP)."
  fi
fi

echo "[DONE] Summary: ${SUMMARY_FILE}"
cat "${SUMMARY_FILE}"
