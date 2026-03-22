#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${ROOT_DIR}/state.env"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "state.env not found. Run scripts/deploy-ec2-alb.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "$STATE_FILE"

FAILOVER_TEST="${FAILOVER_TEST:-false}"

echo "[INFO] Region: $AWS_REGION"
echo "[INFO] ALB DNS: $ALB_DNS"

echo "[CHECK] EC2 instances"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID_1" "$INSTANCE_ID_2" --region "$AWS_REGION" \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress}'

echo "[CHECK] Target health"
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$AWS_REGION" \
  --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}'

echo "[CHECK] ALB and listener"
aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].{DNS:DNSName,State:State.Code,Scheme:Scheme}'
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
  --query 'Listeners[].{Port:Port,Protocol:Protocol,ListenerArn:ListenerArn}'

echo "[CHECK] Request distribution (10 requests)"
for i in $(seq 1 10); do
  body=$(curl -s "http://${ALB_DNS}" || true)
  server=$(echo "$body" | sed -n 's|.*Server: \(i-[a-zA-Z0-9]*\).*|\1|p')
  echo "$i,$server"
  sleep 1
done

if [[ "$FAILOVER_TEST" == "true" ]]; then
  echo "[CHECK] Failover test enabled: stop one instance and test again"
  aws ec2 stop-instances --instance-ids "$INSTANCE_ID_2" --region "$AWS_REGION" >/dev/null
  aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID_2" --region "$AWS_REGION"

  echo "[CHECK] Post-stop target health"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$AWS_REGION" \
    --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}'

  echo "[CHECK] Post-stop requests (5)"
  for i in $(seq 1 5); do
    body=$(curl -s "http://${ALB_DNS}" || true)
    server=$(echo "$body" | sed -n 's|.*Server: \(i-[a-zA-Z0-9]*\).*|\1|p')
    echo "$i,$server"
    sleep 1
  done
fi
