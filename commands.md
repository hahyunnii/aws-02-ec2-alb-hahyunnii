# commands.md (Execution Log)

## 0) Environment and Preflight
```bash
aws sts get-caller-identity
aws configure get region
date
```
- Key output:
- Interpretation:

## 1) Move to Project
```bash
cd toy-example
pwd
```
- Key output:
- Interpretation:

## 2) Deploy
```bash
export AWS_REGION="us-east-1"
export NAME_PREFIX="ccaws-a2-<student-id>"
bash scripts/deploy-ec2-alb.sh
```
- Key output:
- Interpretation:

## 3) Verify Core Status
```bash
bash scripts/verify-ec2-alb.sh
```
- Key output:
- Interpretation:

## 4) Request Distribution
- Endpoint:
- Result table (request #, response server-id):

## 5) Failover Test
```bash
FAILOVER_TEST=true bash scripts/verify-ec2-alb.sh
```
- What was stopped:
- Service still available after stop: Yes / No
- Evidence summary:

## 6) Failure and Recovery
- Symptom:
- Failed command:
```bash
# paste command
```
- Error message:
- Root cause:
- Fix command:
```bash
# paste command
```
- Re-verification:

## 7) Optional Cleanup
```bash
bash scripts/cleanup-ec2-alb.sh
```
- Key output:
- Interpretation:
