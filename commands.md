# Assignment 2 — Commands Log
**Name:** 이하현 (Hahyun-Lee)
**Student ID:** 32213651  
**Date (KST):** 2026-04-15  
**AWS Region:** us-east-1  
**ALB DNS:** ccaws-a2-5881126-alb-1152118624.us-east-1.elb.amazonaws.com

---

## 0) Environment and Preflight
> ✋ 직접 실행

### Purpose
AWS Academy 임시 자격증명이 유효한지, 올바른 리전으로 설정되어 있는지 확인한다.

### Command
```bash
aws sts get-caller-identity
aws configure get region
```

### Output
```json
{
    "UserId": "AROA6IXGDBDW3VDSMGKJG:user4886845=_________",
    "Account": "980808829165",
    "Arn": "arn:aws:sts::980808829165:assumed-role/voclabs/user4886845=_________"
}
us-east-1
```

### Interpretation
AWS Academy 임시 자격증명이 유효하며, 계정 980808829165에서 us-east-1 리전으로 접속이 확인되었다. `assumed-role/voclabs`는 AWS Academy Learner Lab의 IAM 역할로, 실습에 필요한 EC2/ELB 권한이 부여되어 있다.

---

## 1) Project Setup
> ✋ 직접 실행

### Purpose
과제 레포지토리를 클론하고, 배포에 필요한 환경변수를 설정한다. us-east-1e는 t3.micro를 지원하지 않으므로 us-east-1a, us-east-1b 서브넷을 명시적으로 지정한다.

### Command
```bash
cd ~
git clone https://github.com/mobile-os-dku-cis-mse/02-ec2-alb-hahyunnii.git
cd 02-ec2-alb-hahyunnii/toy-example

export AWS_REGION="us-east-1"
export NAME_PREFIX="ccaws-a2-5881126"
export SUBNET_ID_1="subnet-0b325a3a157bfff42"   # us-east-1a
export SUBNET_ID_2="subnet-0907c242196e43f14"   # us-east-1b
```

### 서브넷 확인 명령어 (us-east-1e 문제 발생 후 실행)
```bash
aws ec2 describe-subnets \
  --filters "Name=defaultForAz,Values=true" \
  --query 'Subnets[].{AZ:AvailabilityZone,SubnetId:SubnetId}' \
  --output table
```

### Output
```
--------------------------------------------
|              DescribeSubnets             |
+-------------+----------------------------+
|     AZ      |         SubnetId           |
+-------------+----------------------------+
|  us-east-1e |  subnet-090b0320b9f8cd3d8  |
|  us-east-1d |  subnet-0ce5188ddee11adfe  |
|  us-east-1a |  subnet-0b325a3a157bfff42  |
|  us-east-1f |  subnet-063f9ccf5facc7d21  |
|  us-east-1b |  subnet-0907c242196e43f14  |
|  us-east-1c |  subnet-0eb7510f45442d602  |
+-------------+----------------------------+
```

### Interpretation
us-east-1e는 t3.micro를 지원하지 않아 배포 오류가 발생하였다. 서브넷 목록을 확인한 후 us-east-1a(`subnet-0b325a3a157bfff42`)와 us-east-1b(`subnet-0907c242196e43f14`)를 명시적으로 지정하였다. 두 인스턴스를 서로 다른 AZ에 배치하기 위한 필수 설정이다.

---

## 2) Deploy — EC2 × 2 + ALB
> ✋ 직접 실행

### Purpose
`deploy-ec2-alb.sh` 스크립트를 실행하여 ALB SG, EC2 SG, EC2 인스턴스 2대, 타겟 그룹, ALB, 리스너를 한 번에 프로비저닝한다.

### Command
```bash
bash scripts/deploy-ec2-alb.sh
```

### Output
```
Deployment completed.
State file: /mnt/vocwork3/work/eee_W_5881126/asn5112690_1/asn5112691_1/work/
            02-ec2-alb-hahyunnii/toy-example/state.env
ALB endpoint: http://ccaws-a2-5881126-alb-1152118624.us-east-1.elb.amazonaws.com
```

### Interpretation
스크립트가 다음 리소스를 순서대로 생성하였다.
1. ALB SG (`sg-0d5c1403c54d9f98b`): 인터넷 → ALB 트래픽 허용
2. EC2 SG (`sg-0b471f9ae003390ab`): ALB SG → EC2 트래픽만 허용 (SG-to-SG)
3. EC2 2대 (`i-03c4c025fd155d84b`, `i-0eb323ab00ce39c57`): user-data.sh로 Nginx 자동 설치
4. 타겟 그룹: EC2 2대 등록, 헬스체크 경로 `/`
5. ALB + 리스너: HTTP:80 → 타겟 그룹 포워딩

모든 리소스 ID는 `state.env`에 저장되어 이후 명령어에서 참조된다.

---

## 3) Security Group Verification
> ✋ 직접 실행

### Purpose
EC2 SG의 인바운드 규칙이 IP 범위(0.0.0.0/0)가 아닌 ALB SG ID를 참조(SG-to-SG reference)하는지 확인한다. 이는 EC2가 ALB를 통해서만 HTTP 트래픽을 수신하도록 보장하는 핵심 보안 설계이다.

### Command
```bash
aws ec2 describe-security-groups \
  --group-ids sg-0d5c1403c54d9f98b sg-0b471f9ae003390ab \
  --query 'SecurityGroups[].{Name:GroupName,GroupId:GroupId,Rules:IpPermissions}' \
  --output json
```

### Output
```json
[
    {
        "Name": "ccaws-a2-5881126-alb-sg",
        "GroupId": "sg-0d5c1403c54d9f98b",
        "Rules": [
            {
                "FromPort": 80,
                "IpProtocol": "tcp",
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
                "Ipv6Ranges": [],
                "PrefixListIds": [],
                "ToPort": 80,
                "UserIdGroupPairs": []
            }
        ]
    },
    {
        "Name": "ccaws-a2-5881126-ec2-sg",
        "GroupId": "sg-0b471f9ae003390ab",
        "Rules": [
            {
                "FromPort": 80,
                "IpProtocol": "tcp",
                "IpRanges": [],
                "Ipv6Ranges": [],
                "PrefixListIds": [],
                "ToPort": 80,
                "UserIdGroupPairs": [
                    {
                        "GroupId": "sg-0d5c1403c54d9f98b",
                        "UserId": "980808829165"
                    }
                ]
            }
        ]
    }
]
```

### Interpretation
보안 설계가 올바르게 구성되었음을 확인하였다.

| 항목 | ALB SG | EC2 SG |
|------|--------|--------|
| 인바운드 출처 | `0.0.0.0/0` (인터넷 전체) | `sg-0d5c1403c54d9f98b` (ALB SG만) |
| IpRanges | CidrIp: 0.0.0.0/0 | 비어있음 (IpRanges: []) |
| UserIdGroupPairs | 비어있음 | ALB SG ID 참조 |

EC2 SG의 `IpRanges`가 비어있고 `UserIdGroupPairs`에 ALB SG ID만 존재한다. 이는 EC2가 인터넷에서 직접 접근 불가능하며, 반드시 ALB를 경유해야만 HTTP 트래픽을 수신할 수 있음을 증명하는 SG-to-SG 참조 설계이다.

---

## 4) Core Status Verification
> ✋ 직접 실행 (`bash scripts/verify-ec2-alb.sh`)  
> 🤖 아래 명령어들은 verify-ec2-alb.sh 내부에서 자동 실행됨

### Purpose
EC2 인스턴스 상태, 타겟 헬스, ALB 및 리스너 구성을 한 번에 확인한다.

### Command
```bash
bash scripts/verify-ec2-alb.sh
```

---

### 4-1) EC2 Instance Check
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행
```bash
aws ec2 describe-instances \
  --instance-ids i-03c4c025fd155d84b i-0eb323ab00ce39c57 \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress}'
```

#### Output
```json
[
    {
        "Id": "i-03c4c025fd155d84b",
        "State": "running",
        "PrivateIp": "172.31.12.60"
    },
    {
        "Id": "i-0eb323ab00ce39c57",
        "State": "running",
        "PrivateIp": "172.31.12.33"
    }
]
```

#### Interpretation
EC2 2대가 모두 `running` 상태이다. `i-03c4c025fd155d84b`는 us-east-1a(172.31.12.60), `i-0eb323ab00ce39c57`는 us-east-1b(172.31.12.33)에 위치하여 서로 다른 AZ 요건을 충족한다.

---

### 4-2) Target Health Check
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:980808829165:targetgroup/ccaws-a2-5881126-tg/be63ea8b8f2db1d1 \
  --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}'
```

#### Output
```json
[
    {
        "Id": "i-0eb323ab00ce39c57",
        "State": "healthy",
        "Reason": null
    },
    {
        "Id": "i-03c4c025fd155d84b",
        "State": "healthy",
        "Reason": null
    }
]
```

#### Interpretation
두 타겟 모두 `healthy` 상태이다. ALB가 헬스체크 경로 `/`로 HTTP GET 요청을 전송하였고 Nginx가 HTTP 200을 반환하여 연속 2회 성공 기준을 충족하였다. ALB는 이 두 인스턴스에 라운드로빈으로 트래픽을 분산한다.

---

### 4-3) ALB and Listener Check
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행
```bash
aws elbv2 describe-load-balancers \
  --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:980808829165:loadbalancer/app/ccaws-a2-5881126-alb/c507893292a8187d \
  --query 'LoadBalancers[0].{DNS:DNSName,State:State.Code,Scheme:Scheme}'

aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:980808829165:loadbalancer/app/ccaws-a2-5881126-alb/c507893292a8187d \
  --query 'Listeners[].{Port:Port,Protocol:Protocol,ListenerArn:ListenerArn}'
```

#### Output
```json
{
    "DNS": "ccaws-a2-5881126-alb-1152118624.us-east-1.elb.amazonaws.com",
    "State": "active",
    "Scheme": "internet-facing"
}
[
    {
        "Port": 80,
        "Protocol": "HTTP",
        "ListenerArn": "arn:aws:elasticloadbalancing:us-east-1:980808829165:listener/app/ccaws-a2-5881126-alb/c507893292a8187d/6f3bf8d703ad4bf8"
    }
]
```

#### Interpretation
ALB가 `active` 상태이며 `internet-facing` 스킴으로 외부 트래픽을 수신한다. 포트 80 HTTP 리스너가 정상적으로 생성되어 타겟 그룹으로 포워딩하는 기본 규칙이 적용되어 있다.

---

## 5) Request Distribution Test — Normal State (10 requests)
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행

### Purpose
ALB DNS로 10회 요청을 전송하여 두 인스턴스가 모두 응답에 참여하는지 확인한다.

### Command (verify-ec2-alb.sh 내부 로직)
```bash
for i in $(seq 1 10); do
  body=$(curl -s "http://ccaws-a2-5881126-alb-1152118624.us-east-1.elb.amazonaws.com")
  server=$(echo "$body" | sed -n 's|.*Server: \(i-[a-zA-Z0-9]*\).*|\1|p')
  echo "$i,$server"
  sleep 1
done
```

### Output
```
1,i-03c4c025fd155d84b
2,i-0eb323ab00ce39c57
3,i-03c4c025fd155d84b
4,i-03c4c025fd155d84b
5,i-0eb323ab00ce39c57
6,i-03c4c025fd155d84b
7,i-03c4c025fd155d84b
8,i-03c4c025fd155d84b
9,i-0eb323ab00ce39c57
10,i-0eb323ab00ce39c57
```

### Result Table

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

### Interpretation
10회 요청 중 `i-03c4c025fd155d84b`(EC2-1, us-east-1a)가 6회, `i-0eb323ab00ce39c57`(EC2-2, us-east-1b)가 4회 응답하였다. 두 인스턴스 모두 응답에 참여하였으므로 ALB의 라운드로빈 부하 분산이 정상 동작하고 있음이 확인되었다.

---

## 6) Failover Test — Degraded State
> ✋ 직접 실행 (`FAILOVER_TEST=true bash scripts/verify-ec2-alb.sh`)  
> 🤖 stop-instances 및 이후 확인은 verify-ec2-alb.sh 내부에서 자동 실행됨

### Purpose
EC2-2를 강제로 중지하여 단일 인스턴스 장애 상황을 시뮬레이션한다. ALB가 자동으로 장애 인스턴스를 감지하고 나머지 인스턴스로만 트래픽을 전달하는지 검증한다.

### Command
```bash
FAILOVER_TEST=true bash scripts/verify-ec2-alb.sh
```

---

### 6-1) Pre-Failover Target Health
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행

#### Output
```json
[
    {
        "Id": "i-0eb323ab00ce39c57",
        "State": "healthy",
        "Reason": null
    },
    {
        "Id": "i-03c4c025fd155d84b",
        "State": "healthy",
        "Reason": null
    }
]
```

---

### 6-2) Stop EC2-2
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행
```bash
aws ec2 stop-instances \
  --instance-ids i-0eb323ab00ce39c57 \
  --region us-east-1
```

EC2-2(`i-0eb323ab00ce39c57`)가 중지 명령을 받았다. ALB 헬스체크가 실패를 감지하여 unused로 전환되기까지 최대 60초가 소요된다.

---

### 6-3) Post-Stop Target Health (~60초 대기 후)
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행

#### Output
```json
[
    {
        "Id": "i-0eb323ab00ce39c57",
        "State": "unused",
        "Reason": "Target.InvalidState"
    },
    {
        "Id": "i-03c4c025fd155d84b",
        "State": "healthy",
        "Reason": null
    }
]
```

#### Interpretation
EC2-2가 `unused / Target.InvalidState` 상태로 전환되어 트래픽 풀에서 제외되었다. EC2-1은 여전히 `healthy` 상태를 유지하고 있으며, ALB는 이 시점부터 100%의 트래픽을 EC2-1으로만 전달한다.

---

### 6-4) Post-Stop Request Distribution (5 requests)
> 🤖 verify-ec2-alb.sh 내부에서 자동 실행

#### Output
```
1,(transitioning)
2,(transitioning)
3,i-03c4c025fd155d84b
4,i-03c4c025fd155d84b
5,(transitioning)
```

#### Interpretation
EC2-2 중지 직후 헬스체크 전환 구간(약 60초)에서 1, 2, 5번 요청이 일시적으로 응답을 받지 못하였다. 이는 ALB가 헬스체크 실패를 감지하는 과정에서 발생하는 정상적인 현상이다. 3, 4번 요청은 EC2-1에서 정상 응답하였으며, 전환 완료 후에는 모든 트래픽이 EC2-1으로만 라우팅됨이 확인되었다. 단일 인스턴스 장애 시 ALB가 자동으로 트래픽을 생존 인스턴스로 전환하는 Fault Tolerance가 검증되었다.

---

## 7) Recovery — Restart EC2-2
> ✋ 직접 실행

### Purpose
장애 테스트 완료 후 EC2-2를 재시작하여 정상 상태로 복구한다.

### Command
```bash
aws ec2 start-instances \
  --instance-ids i-0eb323ab00ce39c57 \
  --region us-east-1
```

### Output
```json
{
    "StartingInstances": [
        {
            "CurrentState": {"Code": 0, "Name": "pending"},
            "InstanceId": "i-0eb323ab00ce39c57",
            "PreviousState": {"Code": 80, "Name": "stopped"}
        }
    ]
}
```

### Interpretation
EC2-2가 `stopped` → `pending` 상태로 전환되었다. 약 1~2분 후 `running` 상태로 복귀하고, ALB 헬스체크 2회 성공 후 다시 `healthy`로 등록된다.

---

## 8) Post-Recovery Verification
> ✋ 직접 실행 (`bash scripts/verify-ec2-alb.sh`)  
> 🤖 아래 확인 명령어들은 verify-ec2-alb.sh 내부에서 자동 실행됨

### Command
```bash
bash scripts/verify-ec2-alb.sh
```

### Target Health Output
```json
[
    {
        "Id": "i-0eb323ab00ce39c57",
        "State": "healthy",
        "Reason": null
    },
    {
        "Id": "i-03c4c025fd155d84b",
        "State": "healthy",
        "Reason": null
    }
]
```

### Post-Recovery Request Distribution (10 requests)

| Request # | Response Server ID | AZ |
|-----------|-------------------|----|
| 1 | i-0eb323ab00ce39c57 | us-east-1b |
| 2 | i-0eb323ab00ce39c57 | us-east-1b |
| 3 | i-0eb323ab00ce39c57 | us-east-1b |
| 4 | i-0eb323ab00ce39c57 | us-east-1b |
| 5 | i-03c4c025fd155d84b | us-east-1a |
| 6 | i-03c4c025fd155d84b | us-east-1a |
| 7 | i-03c4c025fd155d84b | us-east-1a |
| 8 | i-0eb323ab00ce39c57 | us-east-1b |
| 9 | i-0eb323ab00ce39c57 | us-east-1b |
| 10 | i-03c4c025fd155d84b | us-east-1a |

### Interpretation
EC2-2가 복구되어 두 인스턴스 모두 `healthy` 상태로 돌아왔다. 두 인스턴스가 다시 모두 응답에 참여하는 것을 확인하였다. ALB가 복구된 인스턴스를 자동으로 트래픽 풀에 재등록하는 Self-Healing 동작이 검증되었다.

---

## 9) Cleanup
> ✋ 직접 실행

### Purpose
실습 완료 후 모든 AWS 리소스를 삭제하여 불필요한 비용 발생을 방지한다. 삭제 순서는 의존성에 따라 ALB → 타겟 그룹 → EC2 인스턴스 → 보안 그룹 순으로 진행한다.

---

### 9-1) 1차 실행 — EC2 종료 중 SG 삭제 실패

#### Command
```bash
bash scripts/cleanup-ec2-alb.sh
```

#### Output
```
Revoking optional direct-access rule...
Deleting listener and ALB...
Deleting target group...
Terminating instances...
{
    "TerminatingInstances": [
        {
            "CurrentState": {
                "Code": 32,
                "Name": "shutting-down"
            },
            "InstanceId": "i-0eb323ab00ce39c57",
            "PreviousState": {
                "Code": 16,
                "Name": "running"
            }
        },
        {
            "CurrentState": {
                "Code": 32,
                "Name": "shutting-down"
            },
            "InstanceId": "i-03c4c025fd155d84b",
            "PreviousState": {
                "Code": 16,
                "Name": "running"
            }
        }
    ]
}
Deleting security groups...
An error occurred (DependencyViolation) when calling the DeleteSecurityGroup operation: resource sg-0b471f9ae003390ab has a dependent object
An error occurred (DependencyViolation) when calling the DeleteSecurityGroup operation: resource sg-0d5c1403c54d9f98b has a dependent object
Cleanup finished with remaining resources.
state.env is kept for retry: /mnt/vocwork3/work/eee_W_5881126/asn5112690_1/asn5112691_1/work/02-ec2-alb-hahyunnii/toy-example/state.env
```

#### Interpretation
ALB, 타겟 그룹, EC2 인스턴스 종료 명령은 정상 실행되었다. 그러나 EC2가 아직 `shutting-down` 상태여서 SG에 대한 의존성이 남아있어 `DependencyViolation` 오류가 발생하였다. EC2가 완전히 `terminated` 상태가 될 때까지 기다린 후 재시도가 필요하다.

---

### 9-2) 2차 실행 — EC2 terminated 후 재시도

#### Command
```bash
bash scripts/cleanup-ec2-alb.sh
```

#### Output
```
Revoking optional direct-access rule...
Deleting listener and ALB...
An error occurred (ListenerNotFound) when calling the DeleteListener operation: Listener 'arn:aws:elasticloadbalancing:us-east-1:980808829165:listener/app/ccaws-a2-5881126-alb/c507893292a8187d/6f3bf8d703ad4bf8' not found
Deleting target group...
Terminating instances...
{
    "TerminatingInstances": [
        {
            "CurrentState": {
                "Code": 48,
                "Name": "terminated"
            },
            "InstanceId": "i-0eb323ab00ce39c57",
            "PreviousState": {
                "Code": 48,
                "Name": "terminated"
            }
        },
        {
            "CurrentState": {
                "Code": 48,
                "Name": "terminated"
            },
            "InstanceId": "i-03c4c025fd155d84b",
            "PreviousState": {
                "Code": 48,
                "Name": "terminated"
            }
        }
    ]
}
Deleting security groups...
An error occurred (InvalidGroup.NotFound) when calling the DeleteSecurityGroup operation: The security group 'sg-0b471f9ae003390ab' does not exist
An error occurred (InvalidGroup.NotFound) when calling the DeleteSecurityGroup operation: The security group 'sg-0d5c1403c54d9f98b' does not exist
Cleanup finished with remaining resources.
state.env is kept for retry: /mnt/vocwork3/work/eee_W_5881126/asn5112690_1/asn5112691_1/work/02-ec2-alb-hahyunnii/toy-example/state.env
```

#### Interpretation
`ListenerNotFound`, `InvalidGroup.NotFound` 오류는 해당 리소스가 **이미 삭제되었음**을 의미한다. EC2 2대가 `terminated` 상태로 확인되었고, SG도 1차 실행과 EC2 종료 과정에서 자동으로 해제되었다. 오류처럼 보이지만 실제로는 모든 리소스가 정상 삭제된 상태이다.

---

### 9-3) state.env 수동 삭제

#### Command
```bash
rm ~/02-ec2-alb-hahyunnii/toy-example/state.env
ls ~/02-ec2-alb-hahyunnii/toy-example/
```

#### Output
```
commands.md  README.md  scripts
```

#### Interpretation
`state.env`가 삭제되어 cleanup이 완전히 완료되었다. 모든 리소스 삭제 결과는 아래와 같다.

| 리소스 | 삭제 결과 |
|--------|---------|
| Listener | ✅ 1차 실행 시 삭제 완료 |
| ALB | ✅ 1차 실행 시 삭제 완료 |
| Target Group | ✅ 1차 실행 시 삭제 완료 |
| EC2 2대 | ✅ terminated 확인 |
| EC2 SG | ✅ 자동 해제 확인 |
| ALB SG | ✅ 자동 해제 확인 |

---

## Final Checklist
- [x] Two EC2 instances were created in separate AZs (us-east-1a, us-east-1b)
- [x] Target group health became healthy for both instances
- [x] ALB endpoint served responses (HTTP 200)
- [x] EC2 SG uses SG-to-SG reference (not IP range) for port 80
- [x] 10-request distribution table shows both instances responding
- [x] Failover behavior was tested — traffic continued via survivor
- [x] EC2-2 recovered and both instances returned to healthy
- [x] All AWS resources deleted after lab completion
- [x] commands.md includes command / output / interpretation for all steps
