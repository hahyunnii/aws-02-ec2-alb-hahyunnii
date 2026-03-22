#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-ccaws-a2-toy}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/state.env"
USER_DATA_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/user-data.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }
}

require_cmd aws
require_cmd jq

VPC_ID="${VPC_ID:-}"
SUBNET_ID_1="${SUBNET_ID_1:-}"
SUBNET_ID_2="${SUBNET_ID_2:-}"

if [[ -z "$VPC_ID" ]]; then
  VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
fi

if [[ -z "$SUBNET_ID_1" || -z "$SUBNET_ID_2" ]]; then
  SUBNET_TEXT=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
  set -- $SUBNET_TEXT
  SUBNET_ID_1="${1:-}"
  SUBNET_ID_2="${2:-}"
fi

if [[ -z "$VPC_ID" || -z "$SUBNET_ID_1" || -z "$SUBNET_ID_2" ]]; then
  echo "Could not auto-discover VPC/subnets. Set VPC_ID, SUBNET_ID_1, SUBNET_ID_2 and retry."
  exit 1
fi

AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text --region "$AWS_REGION")

ALB_SG_NAME="${NAME_PREFIX}-alb-sg"
EC2_SG_NAME="${NAME_PREFIX}-ec2-sg"
TG_NAME="${NAME_PREFIX}-tg"
ALB_NAME="${NAME_PREFIX}-alb"

ALB_SG_ID=$(aws ec2 create-security-group --group-name "$ALB_SG_NAME" --description "ALB SG for $NAME_PREFIX" --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'GroupId' --output text)
EC2_SG_ID=$(aws ec2 create-security-group --group-name "$EC2_SG_NAME" --description "EC2 SG for $NAME_PREFIX" --vpc-id "$VPC_ID" --region "$AWS_REGION" --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$ALB_SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$EC2_SG_ID" --protocol tcp --port 80 --source-group "$ALB_SG_ID" --region "$AWS_REGION"

read -r INSTANCE_ID_1 INSTANCE_ID_2 < <(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --security-group-ids "$EC2_SG_ID" \
  --subnet-id "$SUBNET_ID_1" \
  --user-data "file://${USER_DATA_FILE}" \
  --count 2 \
  --region "$AWS_REGION" \
  --query 'Instances[].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID_1" "$INSTANCE_ID_2" --region "$AWS_REGION"

TG_ARN=$(aws elbv2 create-target-group \
  --name "$TG_NAME" \
  --protocol HTTP \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --target-type instance \
  --health-check-path / \
  --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 register-targets --target-group-arn "$TG_ARN" --targets Id="$INSTANCE_ID_1" Id="$INSTANCE_ID_2" --region "$AWS_REGION"

ALB_ARN=$(aws elbv2 create-load-balancer \
  --name "$ALB_NAME" \
  --subnets "$SUBNET_ID_1" "$SUBNET_ID_2" \
  --security-groups "$ALB_SG_ID" \
  --scheme internet-facing \
  --type application \
  --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].DNSName' --output text)

LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --region "$AWS_REGION" \
  --query 'Listeners[0].ListenerArn' --output text)

cat > "$STATE_FILE" <<STATE
AWS_REGION=$AWS_REGION
NAME_PREFIX=$NAME_PREFIX
VPC_ID=$VPC_ID
SUBNET_ID_1=$SUBNET_ID_1
SUBNET_ID_2=$SUBNET_ID_2
ALB_SG_ID=$ALB_SG_ID
EC2_SG_ID=$EC2_SG_ID
INSTANCE_ID_1=$INSTANCE_ID_1
INSTANCE_ID_2=$INSTANCE_ID_2
TG_ARN=$TG_ARN
ALB_ARN=$ALB_ARN
ALB_DNS=$ALB_DNS
LISTENER_ARN=$LISTENER_ARN
STATE

echo "Deployment completed."
echo "State file: $STATE_FILE"
echo "ALB endpoint: http://$ALB_DNS"
