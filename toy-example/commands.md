# Assignment 2 Toy Example - Commands Log Template

## 0) Environment Check
```bash
aws sts get-caller-identity
aws configure get region
date
```
- Key output:
- Interpretation:

## 1) Deploy
```bash
bash scripts/deploy-ec2-alb.sh
```
- Key output:
- Interpretation:

## 2) Verify Core Status
```bash
bash scripts/verify-ec2-alb.sh
```
- Key output:
- Interpretation:

## 3) Request Distribution (10 calls)
- Endpoint:
- Result table (request #, response server-id):

## 4) Failover Test
```bash
FAILOVER_TEST=true bash scripts/verify-ec2-alb.sh
```
- What was stopped:
- Service still available after stop: Yes / No
- Evidence summary:

## 5) Failure and Recovery Record
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

## 6) Optional Cleanup
```bash
bash scripts/cleanup-ec2-alb.sh
```
- Key output:
- Interpretation:

---

## 7) Extended Benchmark (Optional)

### 7-1) Enable direct access
```bash
DIRECT_CIDR="0.0.0.0/0" bash scripts/enable-direct-access.sh
```
- Key output:
- Interpretation:

### 7-2) Run benchmark (ALB vs Direct)
```bash
REQUESTS=200 CONCURRENCY=20 TARGET_MODE=all bash scripts/benchmark-ec2-alb.sh
```
- Summary file: `benchmark/summary.csv`
- Key findings (ALB vs direct):

### 7-3) Disable direct access
```bash
bash scripts/disable-direct-access.sh
```
- Key output:
- Interpretation:

## Final Checklist
- [ ] Two EC2 instances were created and verified
- [ ] Target group health became healthy
- [ ] ALB endpoint served responses
- [ ] Failover behavior was tested
- [ ] commands.md includes command/output/interpretation
