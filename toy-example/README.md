# Toy Example: Assignment 2 (EC2 + ALB)

This standalone toy example mirrors Assignment 2 with minimal app complexity.
Focus on cloud operations: EC2 provisioning, SG separation, target health, and failover evidence.

## Included
- `scripts/user-data.sh`: bootstrap Nginx page with instance ID
- `scripts/deploy-ec2-alb.sh`: create EC2 x2 + Target Group + ALB + Listener
- `scripts/verify-ec2-alb.sh`: required evidence checks and request distribution test
- `scripts/cleanup-ec2-alb.sh`: delete ALB/TG/instances/SGs
- `scripts/enable-direct-access.sh`: temporarily allow direct HTTP access to EC2 instances
- `scripts/benchmark-ec2-alb.sh`: benchmark ALB vs direct instance endpoints
- `scripts/disable-direct-access.sh`: revoke direct-access rule after benchmark
- `commands.md`: submission log template

## Prerequisites
- AWS Academy Lab started (`Start Lab`)
- CLI identity works:
```bash
aws sts get-caller-identity
aws configure get region
```

## Remote Node Credential Setup Example
If `aws sts get-caller-identity` fails on a remote node, clear old credentials and export fresh temporary credentials from the active AWS Academy or Learner Lab session.

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

export AWS_ACCESS_KEY_ID="ASIAEXAMPLE123456789"
export AWS_SECRET_ACCESS_KEY="exampleSecretKeyValue1234567890example"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEExampleVeryLongSessionTokenValue"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"

env | rg '^AWS_'
aws configure list
aws sts get-caller-identity
```

Notes:
- replace the example values with the real temporary credentials from the lab portal
- do not omit `AWS_SESSION_TOKEN`
- run the exports in the same shell session where you will run the toy example commands

If you see `ExpiredToken`, your temporary credentials were valid but have expired.
Clear the old environment variables, confirm the lab is still active, copy fresh credentials from the lab portal, export them again, and rerun `aws sts get-caller-identity`.

## Quick Start
1. Move to the toy example directory:
```bash
cd toy-example
```

2. (Optional) Set names/region:
```bash
export AWS_REGION="us-east-1"
export NAME_PREFIX="ccaws-a2-<student-id>"
```

3. Deploy:
```bash
bash scripts/deploy-ec2-alb.sh
```

4. Verify:
```bash
bash scripts/verify-ec2-alb.sh
```

5. Optional failover test:
```bash
FAILOVER_TEST=true bash scripts/verify-ec2-alb.sh
```

## Expected Evidence
- EC2 instance status
- Target health (`healthy`)
- ALB/listener configuration
- 10 request result table showing load distribution
- Failover result after stopping one instance

## Extended Benchmark (ALB vs Direct)
Use this optional section to compare ALB path and direct-instance path under workload.

1. Enable direct HTTP access (temporary):
```bash
DIRECT_CIDR="0.0.0.0/0" bash scripts/enable-direct-access.sh
```

2. Run benchmark:
```bash
REQUESTS=200 CONCURRENCY=20 TARGET_MODE=all bash scripts/benchmark-ec2-alb.sh
```

3. Revoke direct access:
```bash
bash scripts/disable-direct-access.sh
```

Benchmark output:
- Summary CSV: `benchmark/summary.csv`
- Raw outputs: `benchmark/*.ab.txt` or `benchmark/*.curl.txt`

## Cleanup
```bash
bash scripts/cleanup-ec2-alb.sh
```
