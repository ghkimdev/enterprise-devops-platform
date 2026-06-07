# Rundeck 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```bash
# docker-compose.yml에 추가
rundeck:
  build:
    context: ./rundeck
    dockerfile: docker/Dockerfile
  hostname: rundeck.example.com
  container_name: cicd-rundeck
  restart: unless-stopped
  ports:
    - "4440:4440"
  environment:
    RUNDECK_GRAILS_URL: https://rundeck.example.com
    RUNDECK_SERVER_FORWARDED: "true"
    RUNDECK_JAAS_MODULES_0: JettyCombinedLdapLoginModule
    RUNDECK_JAAS_LDAP_PROVIDERURL: ldaps://ldap:636
    RUNDECK_JAAS_LDAP_BINDDN: cn=admin,dc=example,dc=com
    RUNDECK_JAAS_LDAP_BINDPASSWORD: AdminPass123
    RUNDECK_JAAS_LDAP_USERBASEDN: ou=users,dc=example,dc=com
    RUNDECK_JAAS_LDAP_ROLEBASEDN: ou=roles,dc=example,dc=com
  volumes:
    - rundeck_data:/home/rundeck/server/data
  networks:
    - cicd-net
  depends_on:
    - ldap

# 실행
docker-compose up -d rundeck

# 접속 (2-3분 대기)
https://localhost:4440
# 기본 계정: admin / admin
```

---

## 📋 프로젝트 설정 (Quick Start)

### 1. 새 프로젝트 생성

```
Projects → New Project

기본 설정:
├─ Project Name: Demo
├─ Description: Demo project for testing
├─ SSH Key Storage: Create new
├─ Default Node Executor: SSH
└─ Create
```

### 2. Node 추가 (실행 대상 서버)

```
Project Settings → Nodes → Add Node

Node 설정:
├─ Node name: web-server-01
├─ Hostname: 192.168.1.100
├─ Username: deploy-user
├─ SSH Key Path: /var/lib/rundeck/.ssh/id_rsa
├─ Port: 22
├─ OS Name: Linux
├─ Architecture: x86_64
└─ Add Node
```

### 3. SSH Key 설정

```bash
# Rundeck 컨테이너 접속
docker exec -it cicd-rundeck bash

# SSH 키 생성
ssh-keygen -t rsa -f /var/lib/rundeck/.ssh/id_rsa -N ""

# 공개 키를 원격 서버에 설정
ssh-copy-id -i /var/lib/rundeck/.ssh/id_rsa.pub deploy-user@192.168.1.100
```

---

## 📝 Job 생성 및 관리

### 1. 간단한 Shell Job

```yaml
# Jobs → New Job → YAML

name: Simple Echo Job
description: Print environment information
project: Demo

execution:
  - type: command
    command: |
      echo "User: $(whoami)"
      echo "Host: $(hostname)"
      echo "Date: $(date)"
      echo "PWD: $(pwd)"
```

### 2. 멀티 스텝 Job

```yaml
name: Deploy Application
description: Deploy app to servers
project: Demo

executionStrategy:
  keepgoing: false
  
steps:
  - type: command
    command: echo "Starting deployment..."
    
  - type: command
    command: |
      cd /opt/app
      git pull origin main
      mvn clean package -DskipTests
      
  - type: command
    command: |
      systemctl restart app-service
      sleep 5
      curl -f http://localhost:8080/health || exit 1
      
  - type: command
    command: echo "Deployment completed successfully"

nodefilters:
  dispatch:
    rankAttribute: tags
    rankOrder: ascending
    threadcount: 1
  filter: 'tag: app-server'

onstart:
  - exec: echo "Job started by ${job.username} on ${job.execid}"

onsuccess:
  - exec: echo "Job completed successfully"

onfailure:
  - exec: echo "Job failed!"
```

### 3. 매개변수가 있는 Job

```yaml
name: Deploy with Parameters
description: Deploy specific version to environment
project: Demo

options:
  - name: version
    description: Application version
    value: "1.0.0"
    required: true
    
  - name: environment
    description: Target environment
    values:
      - dev
      - staging
      - production
    value: dev
    required: true
    
  - name: skip_tests
    description: Skip tests
    type: checkbox
    value: "false"

execution:
  - type: command
    command: |
      echo "Deploying version ${option.version} to ${option.environment}"
      if [ "${option.skip_tests}" = "true" ]; then
        echo "Skipping tests..."
      else
        echo "Running tests..."
      fi
```

### 4. 조건부 실행 (If/Else)

```yaml
name: Conditional Deployment
description: Deploy based on environment
project: Demo

options:
  - name: env
    values: [dev, prod]
    value: dev

steps:
  - type: command
    command: |
      if [ "${option.env}" = "prod" ]; then
        echo "Deploying to PRODUCTION with approval"
        # Production deploy logic
      else
        echo "Deploying to DEV"
        # Dev deploy logic
      fi
```

### 5. Job 그룹 (폴더 구조)

```
Jobs 계층:
├─ CI
│  ├─ Build
│  ├─ Test
│  └─ Package
├─ Deployment
│  ├─ Deploy to Dev
│  ├─ Deploy to Staging
│  └─ Deploy to Production
└─ Operations
   ├─ Health Check
   ├─ Cleanup
   └─ Backup
```

Job ID: `ci/build`, `deployment/deploy-to-dev` 등으로 참조 가능

---

## 🔗 Job 통합 및 트리거

### 1. Job 연쇄 실행 (Job Reference)

```yaml
name: Build and Deploy Pipeline
description: Chain multiple jobs
project: Demo

execution:
  - type: jobref
    name: ci/build
    arg: "-version 1.0.0"
    
  - type: jobref
    name: ci/test
    
  - type: jobref
    name: deployment/deploy-to-dev
    
  - type: command
    command: echo "Full pipeline completed"
```

### 2. Webhook 트리거

```yaml
name: Deploy on Git Push
description: Triggered by GitHub webhook
project: Demo

execution:
  - type: command
    command: |
      git pull origin main
      mvn clean package
      systemctl restart app
```

**GitHub Webhook 설정**:
```
Settings → Webhooks → Add webhook

Payload URL: https://rundeck.example.com/api/18/webhooks/Demo/webhook-trigger
Content type: application/json
Trigger events: Push events
```

### 3. 스케줄 기반 실행

```yaml
name: Scheduled Backup
description: Daily backup job
project: Demo

schedule:
  day: "*"
  month: "*"
  hour: "02"
  minute: "00"
  weekday: "*"

execution:
  - type: command
    command: |
      /opt/scripts/backup.sh
      /opt/scripts/cleanup-old-backups.sh
```

---

## 🔐 인증 및 권한 설정

### 1. LDAP 통합 설정

```properties
# /etc/rundeck/rundeck-config.properties

# LDAP 인증 모듈
rundeck.auth.module.0=JettyCombinedLdapLoginModule
rundeck.auth.module.0.providerUrl=ldap://ldap:389
rundeck.auth.module.0.bindDn=cn=admin,dc=example,dc=com
rundeck.auth.module.0.bindPassword=AdminPass123
rundeck.auth.module.0.userBaseDn=ou=users,dc=example,dc=com
rundeck.auth.module.0.userRdnAttribute=cn
rundeck.auth.module.0.userIdAttribute=uid
rundeck.auth.module.0.userPasswordAttribute=userPassword
rundeck.auth.module.0.userObjectClass=inetOrgPerson
rundeck.auth.module.0.roleBaseDn=ou=roles,dc=example,dc=com
rundeck.auth.module.0.roleNameAttribute=cn
rundeck.auth.module.0.roleMemberAttribute=member
rundeck.auth.module.0.roleObjectClass=groupOfNames
```

### 2. 프로젝트 권한 설정

```
Project Settings → Access Control → Edit Policy

규칙 예시:
description: Demo project policy
context:
  project: Demo

for:
  - allow: [read, run, kill] of job
    match:
      name: '.*'
    by:
      username: 'rundeck-admin'
      
  - allow: [read, run] of job
    match:
      name: 'ci/.*'
    by:
      group: 'rundeck-operators'
      
  - allow: [read] of job
    by:
      group: 'ci-cd-team'
```

---

## 📊 주요 명령어 (CLI)

### 1. Job 리스트 조회

```bash
# 모든 Job 리스트
curl -X GET https://rundeck.example.com/api/18/projects/Demo/jobs \
  -H "X-Rundeck-Auth-Token: $TOKEN"

# JSON 형식
curl -X GET https://rundeck.example.com/api/18/projects/Demo/jobs \
  -H "X-Rundeck-Auth-Token: $TOKEN" \
  -H "Accept: application/json" | jq
```

### 2. Job 실행

```bash
# Job 즉시 실행
curl -X POST https://rundeck.example.com/api/18/project/Demo/jobs/$JOB_ID/run \
  -H "X-Rundeck-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "options": {
      "version": "1.0.0",
      "environment": "dev"
    }
  }'

# 또는 CLI
rd run -i $JOB_ID -a version=1.0.0 -a environment=dev
```

### 3. Job 실행 결과 확인

```bash
# 실행 로그 조회
curl -X GET https://rundeck.example.com/api/18/project/Demo/executions/$EXEC_ID \
  -H "X-Rundeck-Auth-Token: $TOKEN"

# 실시간 로그 스트리밍
curl -X GET https://rundeck.example.com/api/18/project/Demo/executions/$EXEC_ID/output \
  -H "X-Rundeck-Auth-Token: $TOKEN"
```

### 4. Job 목록 내보내기/가져오기

```bash
# YAML로 내보내기
curl -X GET https://rundeck.example.com/api/18/project/Demo/jobs/export \
  -H "X-Rundeck-Auth-Token: $TOKEN" \
  -H "Accept: application/yaml" > jobs.yaml

# 임포트
curl -X POST https://rundeck.example.com/api/18/project/Demo/jobs/import \
  -H "X-Rundeck-Auth-Token: $TOKEN" \
  -H "Content-Type: application/yaml" \
  --data-binary @jobs.yaml
```

---

## 📈 모니터링 및 로깅

### 1. 실행 히스토리 조회

```bash
# 최근 실행 10개
curl -X GET "https://rundeck.example.com/api/18/project/Demo/executions?max=10" \
  -H "X-Rundeck-Auth-Token: $TOKEN" | jq

# 특정 Job의 실행 히스토리
curl -X GET "https://rundeck.example.com/api/18/project/Demo/jobs/$JOB_ID/executions" \
  -H "X-Rundeck-Auth-Token: $TOKEN"
```

### 2. 실행 통계

```bash
# Job별 실행 횟수
curl -X GET https://rundeck.example.com/api/18/stats \
  -H "X-Rundeck-Auth-Token: $TOKEN" | jq
```

---

## 🔍 디버깅

### Job 실행 로그 확인

```bash
# 컨테이너 로그
docker logs -f cicd-rundeck

# Rundeck 애플리케이션 로그
docker exec cicd-rundeck tail -f /var/log/rundeck/rundeck.log

# Job 실행 로그
docker exec cicd-rundeck tail -f /var/lib/rundeck/logs/job-executions.log
```

### 일반적인 문제

```
1. LDAP 연결 실패
   → rundeck-config.properties 의 LDAP 설정 확인
   → LDAP 서버 포트 확인 (389 또는 636)

2. Job 권한 거부
   → 프로젝트 ACL 정책 확인
   → 사용자 그룹 멤버십 확인

3. SSH 연결 실패
   → SSH 키 권한 확인 (600)
   → 원격 서버 SSH 설정 확인
   → 방화벽 규칙 확인

4. Job 실행 타임아웃
   → Job timeout 설정 조정
   → 원격 서버 성능 확인
```

---

## 🎯 실무 예제

### 예제 1: 배포 자동화 Job

```yaml
name: Production Deployment
description: Deploy to production servers
project: Demo

options:
  - name: version
    description: Release version
    required: true
  - name: skip_tests
    type: checkbox
    value: "false"

steps:
  - type: command
    command: echo "=== Pre-deployment checks ==="
    
  - type: command
    command: |
      if ! curl -f https://nexus.example.com/repository/releases/app/${option.version}/app-${option.version}.jar; then
        echo "Artifact not found in Nexus!"
        exit 1
      fi
    
  - type: command
    command: echo "=== Downloading artifact ==="
    
  - type: command
    command: |
      curl -o /tmp/app-${option.version}.jar \
        https://nexus.example.com/repository/releases/app/${option.version}/app-${option.version}.jar
    
  - type: command
    command: echo "=== Stopping old service ==="
    
  - type: command
    command: systemctl stop app-service
    
  - type: command
    command: echo "=== Deploying new version ==="
    
  - type: command
    command: |
      cp /tmp/app-${option.version}.jar /opt/app/app.jar
      chown app:app /opt/app/app.jar
      
  - type: command
    command: echo "=== Starting service ==="
    
  - type: command
    command: systemctl start app-service
    
  - type: command
    command: echo "=== Health check ==="
    
  - type: command
    command: sleep 10 && curl -f http://localhost:8080/health

nodefilters:
  dispatch:
    threadcount: 1
  filter: 'tag: prod-server'

retry:
  enabled: true
  max: 3
  delay: 30

onsuccess:
  - exec: |
      echo "Deployment v${option.version} completed successfully!"
      # Send notification
      
onfailure:
  - exec: |
      echo "Deployment failed! Rolling back..."
      systemctl restart app-service
```

### 예제 2: 정기 백업 Job

```yaml
name: Daily Server Backup
description: Backup all critical data
project: Demo

schedule:
  hour: "03"
  minute: "00"

steps:
  - type: command
    command: echo "Starting backup at $(date)"
    
  - type: command
    command: |
      /usr/local/bin/backup-database.sh \
        --backup-dir=/backup/db \
        --retention=30
        
  - type: command
    command: |
      /usr/local/bin/backup-files.sh \
        --source=/opt/app/data \
        --backup-dir=/backup/files \
        --retention=7
        
  - type: command
    command: |
      find /backup -name "*.tar.gz" -newer /tmp/backup.marker | \
      while read file; do
        s3cmd put "$file" s3://backups/
      done
      
  - type: command
    command: echo "Backup completed at $(date)"

nodefilters:
  filter: 'tag: backup-server'
```

---

## 📱 API Token 설정

### Token 생성

```
User Profile → API Token → Generate Token

토큰 활용:
curl -X GET https://rundeck.example.com/api/18/projects \
  -H "X-Rundeck-Auth-Token: $TOKEN"
```

---

## 🎯 빠른 참조

```bash
# Job 실행
rd run -i $JOB_ID

# 매개변수 포함
rd run -i $JOB_ID -a version=1.0.0 -a env=prod

# 실행 결과 대기
rd run -i $JOB_ID -w -t $TIMEOUT

# Job 목록
rd jobs list

# Job 상세 정보
rd jobs info $JOB_ID

# Project 목록
rd projects list

# Node 목록
rd nodes list --project Demo

# 실행 히스토리
rd executions list --project Demo --max 10
```

**Rundeck를 5분 안에 완벽하게 설정할 수 있습니다!** 🚀
