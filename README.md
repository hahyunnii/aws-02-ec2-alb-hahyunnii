# EC2 ALB Template

This repository is the starter template for Assignment 2: EC2 + ALB High-Availability Setup.

## Repository Layout
- `report.md`: student submission report
- `commands.md`: command log with key outputs and interpretations
- `user-data.sh`: submission copy of the EC2 bootstrap script
- `toy-example/`: deployment, verification, benchmark, and cleanup scripts
- `templates/`: original blank templates for reference

## What To Do
1. Review the assignment scope in this repository.
2. Use the files under `toy-example/` to deploy and validate the EC2 + ALB setup.
3. Copy your final bootstrap content into `user-data.sh` if you customize it.
4. Fill `report.md` and `commands.md` with your own evidence.
5. Commit and push your work to your assignment repository.

## Assignment Scope
- Provision two EC2 instances using User Data
- Build ALB + Target Group routing
- Validate round-robin and failure behavior

## Requirements
1. Launch two EC2 instances.
2. Configure security groups with separation of concerns for ALB and EC2.
3. Create a target group and register both instances.
4. Create an ALB and listener, then verify target health.
5. Run repeated requests and compare behavior before and after stopping one instance.

## Required CLI Evidence
```bash
aws ec2 describe-instances --instance-ids <id1> <id2>
aws elbv2 describe-target-health --target-group-arn <tg-arn>
aws elbv2 describe-load-balancers --names <alb-name>
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>
```

## Submission Files
- `report.md`
- `commands.md`
- `user-data.sh`
- request result table for repeated ALB calls

## Grading
- Architecture correctness: 1.5
- Validation quality (round-robin + failure): 1.0
- Security and operations explanation: 1.0
- CLI reproducibility: 0.5
