# Assignment 2 Report: EC2 + ALB

## 1) Student Info
- Name:
- Student ID:
- Date (KST):
- AWS Region:

## 2) Objective and Scope
- Objective:
- Scope:

## 3) Architecture Summary
- EC2 instance count and type:
- Security group design (ALB SG / EC2 SG):
- Target group health check path:
- ALB listener configuration:
- ALB DNS:

## 4) Implementation Notes (What and Why)
1. EC2 provisioning and bootstrap method:
2. SG separation and traffic path:
3. Target registration and health check tuning:
4. ALB routing verification:

## 5) Validation Results
- Both targets healthy: Yes / No
- Repeated ALB requests show service response: Yes / No
- One-instance stop test performed: Yes / No
- Degraded mode still serves traffic: Yes / No

## 6) Failure and Recovery
- Symptom:
- Root cause:
- Fix:
- Re-verification:

## 7) Reproducibility Checklist
- [ ] `commands.md` includes normal and degraded-state evidence
- [ ] Health-check evidence attached
- [ ] SG rationale is explained
- [ ] Commands can be replayed end-to-end
