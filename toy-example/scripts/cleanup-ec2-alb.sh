#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT_DIR}/state.env"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "state.env not found. Nothing to clean."
  exit 0
fi

# shellcheck disable=SC1090
source "$STATE_FILE"

HAS_FAILURE=0

run_or_mark_fail() {
  if ! "$@"; then
    HAS_FAILURE=1
  fi
}

echo "Revoking optional direct-access rule..."
if [[ -n "${DIRECT_SG_RULE_ID:-}" ]]; then
  run_or_mark_fail aws ec2 revoke-security-group-ingress --group-id "$EC2_SG_ID" --security-group-rule-ids "$DIRECT_SG_RULE_ID" --region "$AWS_REGION"
elif [[ -n "${DIRECT_ACCESS_CIDR:-}" ]]; then
  run_or_mark_fail aws ec2 revoke-security-group-ingress --group-id "$EC2_SG_ID" --protocol tcp --port 80 --cidr "$DIRECT_ACCESS_CIDR" --region "$AWS_REGION"
fi

echo "Deleting listener and ALB..."
if [[ -n "${LISTENER_ARN:-}" ]]; then
  run_or_mark_fail aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" --region "$AWS_REGION"
fi
if [[ -n "${ALB_ARN:-}" ]]; then
  run_or_mark_fail aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION"
  run_or_mark_fail aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION"
fi

echo "Deleting target group..."
if [[ -n "${TG_ARN:-}" ]]; then
  run_or_mark_fail aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_REGION"
fi

echo "Terminating instances..."
if [[ -n "${INSTANCE_ID_1:-}" || -n "${INSTANCE_ID_2:-}" ]]; then
  run_or_mark_fail aws ec2 terminate-instances --instance-ids "$INSTANCE_ID_1" "$INSTANCE_ID_2" --region "$AWS_REGION"
fi

echo "Deleting security groups..."
if [[ -n "${EC2_SG_ID:-}" ]]; then
  run_or_mark_fail aws ec2 delete-security-group --group-id "$EC2_SG_ID" --region "$AWS_REGION"
fi
if [[ -n "${ALB_SG_ID:-}" ]]; then
  run_or_mark_fail aws ec2 delete-security-group --group-id "$ALB_SG_ID" --region "$AWS_REGION"
fi

if [[ "$HAS_FAILURE" -eq 0 ]]; then
  rm -f "$STATE_FILE"
  echo "Cleanup completed. state.env removed."
else
  echo "Cleanup finished with remaining resources."
  echo "state.env is kept for retry: $STATE_FILE"
  exit 1
fi
