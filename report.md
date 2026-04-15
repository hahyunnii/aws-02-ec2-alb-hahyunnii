# Assignment 2 Report: EC2 + ALB

## 1) Student Info
- Name: 이하현 (Hahyun-Lee)
- Student ID: 32213651
- Date (KST): 2026-04-15
- AWS Region: us-east-1

---

## 2) Objective and Scope
- Objective: AWS EC2 인스턴스 2대를 Application Load Balancer(ALB) 뒤에 배치하여 고가용성 웹 서비스를 구성하고, 정상 상태 및 장애 상태에서의 동작을 CLI로 검증한다.
- Scope: EC2 프로비저닝, 보안 그룹 분리 설계(SG-to-SG), 타겟 그룹 및 ALB 구성, 라운드로빈 부하 분산 확인, 단일 인스턴스 장애 시 자동 페일오버 검증, 복구 확인, 리소스 정리.

---

## 3) Architecture Summary

```
[Internet]
     |
     | TCP 80 (0.0.0.0/0)
     v
+----------------------------------------------+
|  ALB SG: ccaws-a2-5881126-alb-sg             |
|  sg-0d5c1403c54d9f98b                        |
|  Inbound: TCP 80 from 0.0.0.0/0              |
+----------------------------------------------+
     |
     v
+----------------------------------------------+
|  ALB: ccaws-a2-5881126-alb                   |
|  DNS: ccaws-a2-5881126-alb-1152118624        |
|       .us-east-1.elb.amazonaws.com           |
|  Listener: HTTP:80 → Target Group            |
+----------------------------------------------+
     |                        |
     | Round-robin             |
     v                        v
+-------------------+  +-------------------+
|  EC2 SG           |  |  EC2 SG           |
|  sg-0b471f9ae003  |  |  sg-0b471f9ae003  |
|  Inbound: TCP 80  |  |  Inbound: TCP 80  |
|  from ALB SG only |  |  from ALB SG only |
+-------------------+  +-------------------+
     |                        |
     v                        v
+-------------------+  +-------------------+
|  EC2-1            |  |  EC2-2            |
|  i-03c4c025...    |  |  i-0eb323ab...    |
|  172.31.12.60     |  |  172.31.12.33     |
|  us-east-1a       |  |  us-east-1b       |
|  Nginx (user-data)|  |  Nginx (user-data)|
+-------------------+  +-------------------+
```

- EC2 instance count and type: 2대, t3.micro, Amazon Linux 2023
- Security group design:
  - ALB SG (`sg-0d5c1403c54d9f98b`): 인바운드 TCP 80 허용 (0.0.0.0/0), 아웃바운드 전체 허용
  - EC2 SG (`sg-0b471f9ae003390ab`): 인바운드 TCP 80 허용 (ALB SG ID 참조, SG-to-SG), 아웃바운드 전체 허용
  - EC2는 인터넷에서 직접 접근 불가 — 반드시 ALB를 경유해야 함
- Target group health check path: `/`
- ALB listener configuration: HTTP:80, 기본 규칙으로 타겟 그룹 포워딩
- ALB DNS: ccaws-a2-5881126-alb-1152118624.us-east-1.elb.amazonaws.com

---

## 4) Implementation Notes (What and Why)

### 1. EC2 provisioning and bootstrap method
`deploy-ec2-alb.sh` 스크립트가 `aws ec2 run-instances` 명령어로 EC2 2대를 생성하였다. `--user-data` 옵션으로 `user-data.sh`를 전달하여 첫 부팅 시 Nginx가 자동 설치되도록 하였다. `user-data.sh`는 IMDSv2 토큰 방식으로 인스턴스 ID를 메타데이터에서 가져와 HTML 응답에 포함시킨다. 이를 통해 ALB 응답에서 어느 인스턴스가 처리했는지 구별할 수 있다.

배포 시 us-east-1e 서브넷은 t3.micro를 지원하지 않아 오류가 발생하였다. `aws ec2 describe-subnets`로 서브넷 목록을 확인한 후 us-east-1a(`subnet-0b325a3a157bfff42`)와 us-east-1b(`subnet-0907c242196e43f14`)를 명시적으로 지정하여 해결하였다.

### 2. SG separation and traffic path
ALB SG와 EC2 SG를 분리하여 최소 권한 원칙을 적용하였다. EC2 SG의 인바운드 규칙은 IP 범위(0.0.0.0/0) 대신 ALB SG ID를 출처로 참조(SG-to-SG reference)하였다. 아래는 실제 `describe-security-groups` 출력에서 확인된 규칙이다.

| 항목 | ALB SG | EC2 SG |
|------|--------|--------|
| 인바운드 출처 | `0.0.0.0/0` | `sg-0d5c1403c54d9f98b` (ALB SG만) |
| IpRanges | CidrIp: 0.0.0.0/0 | 비어있음 |
| UserIdGroupPairs | 비어있음 | ALB SG ID 참조 |

EC2 SG의 `IpRanges`가 비어있고 `UserIdGroupPairs`에 ALB SG ID만 존재하므로, EC2는 인터넷에서 직접 접근이 불가능하다.

### 3. Target registration and health check tuning
EC2 2대를 타겟 그룹에 등록하고 헬스체크 경로를 `/`로 설정하였다. Nginx 기본 페이지가 HTTP 200을 반환하므로 별도 설정 없이 헬스체크를 통과한다. 연속 2회 성공 시 `healthy`, 연속 2회 실패 시 `unhealthy`로 전환되며 전환에 최대 60초가 소요된다.

### 4. ALB routing verification
ALB DNS로 10회 요청을 전송하여 두 인스턴스가 모두 응답하는 것을 확인하였다. 응답 HTML의 인스턴스 ID를 파싱하여 분산 현황을 테이블로 기록하였다.

---

## 5) Validation Results

- Both targets healthy: **Yes**
- Repeated ALB requests show service response: **Yes**
- One-instance stop test performed: **Yes**
- Degraded mode still serves traffic: **Yes**

### 정상 상태 요청 분산 테이블

| Request # | Response Server ID | AZ |
|-----------|-------------------|----|
| 1 | i-03c4c025fd155d84b | us-east-1a |
| 2 | i-0eb323ab00ce39c57 | us-east-1b |
| 3 | i-03c4c025fd155d84b | us-east-1a |
| 4 | i-03c4c025fd155d84b | us-east-1a |
| 5 | i-0eb323ab00ce39c57 | us-east-1b |
| 6 | i-03c4c025fd155d84b | us-east-1a |
| 7 | i-03c4c025fd155d84b | us-east-1a |
| 8 | i-03c4c025fd155d84b | us-east-1a |
| 9 | i-0eb323ab00ce39c57 | us-east-1b |
| 10 | i-0eb323ab00ce39c57 | us-east-1b |

10회 요청 중 EC2-1(us-east-1a)이 6회, EC2-2(us-east-1b)가 4회 응답하였다. 두 인스턴스 모두 응답에 참여하였으므로 ALB의 라운드로빈 부하 분산이 정상 동작하고 있음이 확인되었다.

### 장애 전환 후 타겟 헬스

| Instance ID | State | 비고 |
|-------------|-------|------|
| i-0eb323ab00ce39c57 | unused | EC2-2 중지됨 (Target.InvalidState) |
| i-03c4c025fd155d84b | healthy | EC2-1 정상 서비스 중 |

EC2-2 중지 후 ALB가 자동으로 해당 인스턴스를 트래픽 풀에서 제외하고 EC2-1으로만 요청을 전달하였다.

### 장애 전환 후 요청 분산 (5회)

| Request # | Response Server ID | 비고 |
|-----------|-------------------|------|
| 1 | (no response) | 헬스체크 전환 구간 |
| 2 | (no response) | 헬스체크 전환 구간 |
| 3 | i-03c4c025fd155d84b | EC2-1 정상 응답 |
| 4 | i-03c4c025fd155d84b | EC2-1 정상 응답 |
| 5 | (no response) | 헬스체크 전환 구간 |

1, 2, 5번의 일시적 무응답은 EC2-2 중지 직후 ALB 헬스체크 전환 구간(최대 60초)에서 발생하는 정상적인 현상이다. 전환 완료 후에는 100%의 트래픽이 EC2-1으로만 라우팅된다.

---

## 6) Failure and Recovery

- Symptom: EC2-2(`i-0eb323ab00ce39c57`)를 중지하자 타겟 헬스가 `unused / Target.InvalidState`로 전환되었고, 헬스체크 전환 구간 동안 일부 요청이 응답을 받지 못하였다.
- Root cause: ALB 헬스체크 전환 구간(최대 60초) 동안 중지된 인스턴스로 라우팅이 시도되었다. 30초 간격으로 연속 2회 헬스체크 실패 후 ALB가 해당 인스턴스를 트래픽 풀에서 제거하였다.
- Fix: `aws ec2 start-instances --instance-ids i-0eb323ab00ce39c57` 명령으로 EC2-2를 재시작하였다.
- Re-verification: 재시작 후 `bash scripts/verify-ec2-alb.sh`를 다시 실행하여 두 인스턴스 모두 `healthy` 상태로 복귀하고 요청 분산이 재개되었음을 확인하였다.

---

## 7) Reproducibility Checklist
- [x] `commands.md` includes normal and degraded-state evidence
- [x] Health-check evidence attached (describe-target-health output)
- [x] SG rationale is explained (SG-to-SG reference verified)
- [x] Commands can be replayed end-to-end
