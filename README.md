# ALB + Transit Gateway + NLB 기반 고성능 라우팅 아키텍처

이 Terraform 구성은 AWS Application Load Balancer (ALB)와 Network Load Balancer (NLB)를 조합한 고성능 도메인 기반 라우팅 시스템입니다. Transit Gateway를 통해 VPC 간 연결을 제공하며, 엔터프라이즈급 마이크로서비스 아키텍처에 최적화되어 있습니다.

## 아키텍처

```
Internet → Frontend ALB (L7 Host-based routing) → Transit Gateway → Backend NLB (L4 TCP) → EC2 Instances
```

### 상세 구성도
```
                    Internet
                        │
        ┌───────────────┼───────────────┐
        │    Frontend VPC (10.1.0.0/16) │
        │               │               │
        │    ┌─────────────────────┐    │
        │    │   Application LB    │    │
        │    │ (Host-based routing)│    │
        │    │  service-a.example  │    │
        │    │  service-b.example  │    │
        │    └─────────────────────┘    │
        └───────────────┼───────────────┘
                        │
           ┌────────────────────────┐
           │   Transit Gateway      │
           │  (Cross-VPC routing)   │
           └────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │    Backend VPC (10.2.0.0/16)  │
        │               │               │
        │    ┌─────────────────────┐    │
        │    │    Network LB       │    │
        │    │  (High Performance) │    │
        │    │  Port 8080 | 8081   │    │
        │    └─────────────────────┘    │
        │             │        │        │
        │    ┌───────────┐ ┌───────────┐│
        │    │Service A  │ │Service B  ││
        │    │EC2 (8080) │ │EC2 (8081) ││
        │    └───────────┘ └───────────┘│
        └───────────────────────────────┘
```

## 주요 구성 요소

### 1. **Frontend VPC**
- **CIDR**: `10.1.0.0/16`
- **구성**: Internet Gateway + Public Subnets (Multi-AZ)
- **역할**: 인터넷 트래픽 수신 및 ALB 호스팅

### 2. **Backend VPC**
- **CIDR**: `10.2.0.0/16`
- **구성**: Private Subnets (Multi-AZ) + VPC Endpoints
- **역할**: 백엔드 서비스 및 NLB 호스팅

### 3. **Transit Gateway**
- **역할**: VPC 간 중앙 라우팅 허브
- **기능**: 고성능 VPC 간 통신 제공

### 4. **Load Balancers**
- **Frontend ALB**: Layer 7 도메인 기반 라우팅
- **Backend NLB**: Layer 4 고성능 TCP 로드 밸런싱

### 5. **EC2 Instances**
- **Service A**: 포트 8080에서 웹 서비스 제공
- **Service B**: 포트 8081에서 웹 서비스 제공
- **접근**: SSM Session Manager를 통한 보안 접근

## 주요 기능

### **고급 라우팅**
- **L7 라우팅**: Host header 기반 도메인 분기 (`service-a.example.com`, `service-b.example.com`)
- **L4 로드 밸런싱**: NLB를 통한 고성능 TCP 트래픽 분산
- **Multi-AZ**: 고가용성을 위한 다중 가용 영역 구성

### **보안 강화**
- **Private 서브넷**: 백엔드 서비스의 격리된 환경
- **SSM 접근**: SSH 키 없는 안전한 인스턴스 관리
- **VPC Endpoints**: AWS 서비스 접근을 위한 프라이빗 연결
- **Security Groups**: 최소 권한 네트워크 접근 제어

### **성능 최적화**
- **NLB**: 마이크로초 수준의 낮은 지연시간
- **Transit Gateway**: 고대역폭 VPC 간 연결
- **Health Checks**: `/health` 엔드포인트 기반 상태 모니터링

## 배포 방법

### 1. **사전 준비**
```bash
# AWS CLI 구성 확인
aws configure list

# 필요한 권한 확인
aws sts get-caller-identity

# Terraform 초기화
terraform init
```

### 2. **인프라 배포**
```bash
# 배포 계획 검토
terraform plan

# 인프라 배포 실행 (약 5-7분 소요)
terraform apply --auto-approve
```

### 3. **배포 완료 후 출력**
배포가 완료되면 다음 정보들이 출력됩니다:
```bash
# Frontend ALB DNS
frontend_alb_dns = "alb-routing-frontend-alb-xxxxxxxxxxxx.ap-northeast-2.elb.amazonaws.com"

# 테스트 URL
test_urls = {
  service-a = {
    curl_command = "curl -H 'Host: service-a.example.com' http://[ALB_DNS]/"
    domain = "service-a.example.com"
    port = 8080
  }
  service-b = {
    curl_command = "curl -H 'Host: service-b.example.com' http://[ALB_DNS]/"
    domain = "service-b.example.com" 
    port = 8081
  }
}

# SSM 접근 명령어
ssm_connect_commands = {
  service_a_instances = [...]
  service_b_instances = [...]
}
```

## 테스트 방법

### **웹 서비스 테스트**
```bash
# Service A 테스트 (포트 8080)
curl -H 'Host: service-a.example.com' http://[ALB_DNS_NAME]/

# Service B 테스트 (포트 8081)  
curl -H 'Host: service-b.example.com' http://[ALB_DNS_NAME]/

# 헬스 체크 테스트
curl -H 'Host: service-a.example.com' http://[ALB_DNS_NAME]/health
curl -H 'Host: service-b.example.com' http://[ALB_DNS_NAME]/health
```

### **인스턴스 접근**
```bash
# Service A 인스턴스들에 SSM 연결
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx

# Service B 인스턴스들에 SSM 연결  
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

### **로드 밸런싱 확인**
```bash
# 여러 번 요청하여 로드 밸런싱 동작 확인
for i in {1..10}; do
  curl -H 'Host: service-a.example.com' http://[ALB_DNS_NAME]/
  echo "Request $i completed"
done
```

## 커스터마이징

### **terraform.tfvars 파일 예시**
```hcl
aws_region = "ap-northeast-2"
project_name = "my-enterprise-app"
frontend_vpc_cidr = "10.1.0.0/16"
backend_vpc_cidr = "10.2.0.0/16"

domain_mappings = {
  "service-a" = {
    domain = "api.mycompany.com"
    port   = 8080
  }
  "service-b" = {
    domain = "admin.mycompany.com"
    port   = 8081
  }
  "service-c" = {
    domain = "dashboard.mycompany.com"
    port   = 8082
  }
}
```

### **주요 변수 설명**
| 변수명 | 설명 | 기본값 |
|-------|------|-------|
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `project_name` | 프로젝트 이름 (리소스 태그) | `alb-routing` |
| `frontend_vpc_cidr` | Frontend VPC CIDR | `10.1.0.0/16` |
| `backend_vpc_cidr` | Backend VPC CIDR | `10.2.0.0/16` |
| `domain_mappings` | 서비스별 도메인 및 포트 매핑 | 기본 서비스 A, B |

## 리소스 현황

### **생성되는 리소스들**
- **VPCs**: 2개 (Frontend, Backend)
- **Subnets**: 4개 (Public 2개, Private 2개)
- **Load Balancers**: 2개 (ALB 1개, NLB 1개)
- **EC2 Instances**: 4개 (서비스당 2개, Multi-AZ)
- **Transit Gateway**: 1개 + VPC Attachments
- **VPC Endpoints**: 3개 (SSM 관련)
- **Security Groups**: 3개
- **IAM Role/Policy**: SSM 접근용

### **월 예상 비용 (Seoul 리전 기준)**
- **EC2 (t3.micro × 4)**: ~$17 (프리 티어 적용시 무료)
- **ALB**: ~$22
- **NLB**: ~$17  
- **Transit Gateway**: ~$36 + 데이터 전송 요금
- **VPC Endpoints**: ~$7
- **총 예상**: ~$99/월 (프리 티어 제외)

## 운영 관리

### **모니터링**
```bash
# Target Group 상태 확인
aws elbv2 describe-target-health --target-group-arn [TARGET_GROUP_ARN]

# CloudWatch 메트릭 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/elbv2"
```

### **스케일링**
- EC2 인스턴스를 Auto Scaling Group으로 확장 가능
- NLB Target Group에 인스턴스 자동 등록/해제
- ALB에서 추가 도메인 라우팅 규칙 구성

### **장애 대응**
- Multi-AZ 구성으로 단일 AZ 장애시 자동 복구
- Health Check 실패시 자동 트래픽 차단
- CloudWatch 알람 설정 권장

## 리소스 정리

```bash
# 전체 인프라 삭제
terraform destroy --auto-approve

# 특정 리소스만 삭제 (예: EC2 인스턴스)
terraform destroy -target aws_instance.service_a -target aws_instance.service_b
```

## 주의사항

### **보안**
- Production 환경에서는 WAF 적용 권장
- SSL/TLS 인증서 구성 필요
- VPC Flow Logs 활성화 권장

### **성능**
- 대용량 트래픽시 NLB 사전 워밍업 요청
- CloudFront CDN 추가 구성 고려
- RDS/ElastiCache 등 데이터 계층 별도 구성

### **비용**
- 사용하지 않을 때는 반드시 리소스 정리
- Reserved Instance로 장기 비용 절감 가능
- Data Transfer 요금 모니터링 필요

## 지원

문제 발생시 다음 로그를 확인:
- ALB Access Logs (S3 저장 설정 필요)
- VPC Flow Logs  
- CloudWatch 메트릭
- EC2 인스턴스 시스템 로그

---

**구성 완료일**: 2025-08-29  
**Terraform 버전**: >= 1.0  
**AWS Provider**: ~> 5.0