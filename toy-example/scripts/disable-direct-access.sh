#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT_DIR}/state.env"

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "state.env not found. Nothing to disable."
  exit 0
fi

# shellcheck disable=SC1090
source "${STATE_FILE}"

DIRECT_ACCESS_CIDR="${DIRECT_ACCESS_CIDR:-${DIRECT_CIDR:-0.0.0.0/0}}"

echo "[INFO] Disable direct HTTP access"

if [[ -n "${DIRECT_SG_RULE_ID:-}" ]]; then
  aws ec2 revoke-security-group-ingress \
    --group-id "${EC2_SG_ID}" \
    --security-group-rule-ids "${DIRECT_SG_RULE_ID}" \
    --region "${AWS_REGION}" >/dev/null || true
  echo "[INFO] Revoked by rule id: ${DIRECT_SG_RULE_ID}"
else
  aws ec2 revoke-security-group-ingress \
    --group-id "${EC2_SG_ID}" \
    --protocol tcp \
    --port 80 \
    --cidr "${DIRECT_ACCESS_CIDR}" \
    --region "${AWS_REGION}" >/dev/null || true
  echo "[INFO] Revoked by CIDR: ${DIRECT_ACCESS_CIDR}"
fi

echo "Done."
