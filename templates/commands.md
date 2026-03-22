# commands.md (Execution Log)

## 0) Environment and Preflight
```bash
aws sts get-caller-identity
aws configure get region
```
- Key output:
- Interpretation:

## 1) EC2 Provisioning / Check
```bash
aws ec2 describe-instances --filters Name=instance-state-name,Values=running
```
- Key output:
- Interpretation:

## 2) ALB and Target Group Check
```bash
aws elbv2 describe-load-balancers --names <alb-name>
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```
- Key output:
- Interpretation:

## 3) Traffic Test
```bash
curl http://<alb-dns-name>
```
- Key output:
- Interpretation:

## 4) Failure Simulation
```bash
# stop one instance and re-test via ALB
```
- Key output:
- Interpretation:

## 5) Failure and Recovery
- Symptom:
- Error:
- Cause:
- Fix:
