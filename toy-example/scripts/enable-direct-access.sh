#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT_DIR}/state.env"

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "state.env not found. Run scripts/deploy-ec2-alb.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "${STATE_FILE}"

DIRECT_CIDR="${DIRECT_CIDR:-0.0.0.0/0}"

echo "[INFO] Enable direct HTTP access to EC2 SG"
echo "[INFO] SG: ${EC2_SG_ID}, CIDR: ${DIRECT_CIDR}"

OUT=$(aws ec2 authorize-security-group-ingress \
  --group-id "${EC2_SG_ID}" \
  --protocol tcp \
  --port 80 \
  --cidr "${DIRECT_CIDR}" \
  --region "${AWS_REGION}" 2>&1) || true

if echo "$OUT" | grep -q "InvalidPermission.Duplicate"; then
  echo "[INFO] Direct access rule already exists."
  DIRECT_SG_RULE_ID=""
else
  echo "$OUT"
  DIRECT_SG_RULE_ID=$(echo "$OUT" | awk -F'"' '/SecurityGroupRuleId/ {print $4; exit}')
fi

echo "DIRECT_ACCESS_CIDR=${DIRECT_CIDR}" >> "${STATE_FILE}"
if [[ -n "${DIRECT_SG_RULE_ID:-}" ]]; then
  echo "DIRECT_SG_RULE_ID=${DIRECT_SG_RULE_ID}" >> "${STATE_FILE}"
fi

echo "Done."
