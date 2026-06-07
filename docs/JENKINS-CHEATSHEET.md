# Jenkins 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```bash
# docker-compose.yml에 추가
jenkins:
  build:
    context: ./jenkins
    dockerfile: docker/Dockerfile
  hostname: jenkins.example.com
  container_name: cicd-jenkins
  restart: unless-stopped
  ports:
    - "8080:8080"
    - "50000:50000"
  volumes:
    - jenkins_home:/var/jenkins_home
  networks:
    - cicd-net
  depends_on:
    - ldap

# 실행
docker-compose up -d jenkins

# 초기 비밀번호 확인 (1-2분 대기)
docker logs cicd-jenkins | grep -A 5 "Please use the following password"

# 브라우저에서 접속
http://localhost:8080
```

---

## 📋 설정 단계 (Setup Wizard)

### 1단계: 초기 설정

```
1. Jenkins Unlock
   - 위의 초기 비밀번호 입력
   
2. Plugin 설정
   - "Install suggested plugins" 선택
   - 또는 Custom 선택하여:
     * Pipeline
     * Git
     * GitHub Integration
     * SonarQube Scanner
     * Kubernetes
     * Docker Pipeline
     * LDAP
     * Email Extension
     * Slack Notification
     * Role-based Authorization Strategy
     
3. 첫 번째 관리자 계정 생성
   - Username: admin
   - Password: AdminPass123
   - Email: admin@example.com
```

### 2단계: LDAP 연동

```
Manage Jenkins → System Configuration

LDAP:
├─ Server: ldap://ldap:389
├─ root DN: dc=example,dc=com
├─ User search base: ou=users
├─ User search filter: uid={0}
├─ Manager DN: cn=admin,dc=example,dc=com
├─ Manager password: AdminPass123
├─ Display Name LDAP attribute: displayName
└─ Email LDAP attribute: mail

Apply → Save
```

### 3단계: 권한 설정 (Role Strategy)

```
Manage Jenkins → Security

Authorization:
- Role-Based Strategy 선택

Manage Jenkins → Manage and Assign Roles → Manage Roles

Global Roles:
├─ admin: 모든 권한
├─ developer: Job 생성/빌드
└─ viewer: 읽기 전용

Assign Roles:
├─ admin: jenkins-admins 그룹
├─ developer: jenkins-users 그룹
└─ viewer: ci-cd-team 그룹
```

---

## 🔧 자주 사용하는 설정

### Pipeline 기본 구조

```groovy
pipeline {
    agent any
    
    options {
        timeout(time: 1, unit: 'HOURS')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
    }
    
    post {
        always {
            junit 'target/surefire-reports/*.xml'
        }
        success {
            echo "✓ Build successful"
        }
        failure {
            echo "✗ Build failed"
        }
    }
}
```

### Declarative Pipeline with Parameters

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'VERSION', defaultValue: '1.0.0', description: 'Version')
        choice(name: 'ENV', choices: ['dev', 'staging', 'prod'], description: 'Environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip tests')
        text(name: 'NOTES', defaultValue: '', description: 'Release notes')
    }
    
    stages {
        stage('Build') {
            steps {
                script {
                    echo "Building version: ${params.VERSION}"
                    echo "Target environment: ${params.ENV}"
                    if (!params.SKIP_TESTS) {
                        echo "Running tests..."
                    }
                }
            }
        }
    }
}
```

### Approval Gate (승인)

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Approval') {
            steps {
                script {
                    def userInput = input(
                        id: 'Approval',
                        message: 'Deploy to production?',
                        parameters: [
                            string(name: 'APPROVER', defaultValue: 'admin', description: 'Approver name')
                        ]
                    )
                    env.APPROVER = userInput
                }
            }
        }
        
        stage('Deploy') {
            steps {
                echo "Deployed by: ${env.APPROVER}"
            }
        }
    }
}
```

### Multi-branch Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn package'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh './deploy.sh'
            }
        }
    }
}
```

---

## 📦 Plugins 빠른 설치

### Jenkins CLI로 설치

```bash
# Jenkins 컨테이너 접속
docker exec -it cicd-jenkins bash

# 플러그인 설치
java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar \
  -s http://localhost:8080 \
  install-plugin \
  pipeline \
  git \
  github \
  sonar \
  kubernetes \
  docker-workflow \
  ldap \
  email-ext \
  slack \
  role-strategy

# Jenkins 재시작
java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar \
  -s http://localhost:8080 \
  restart
```

### 주요 플러그인 목록

```
필수:
├─ Pipeline (선언형 파이프라인)
├─ Git (Git 통합)
├─ GitHub Integration (GitHub 연동)
├─ GitLab API (GitLab 연동)

품질:
├─ SonarQube Scanner (코드 분석)
├─ JaCoCo Plugin (코드 커버리지)
├─ Performance Plugin (성능 테스트)

컨테이너:
├─ Docker Pipeline (Docker 빌드)
├─ Kubernetes (K8s 배포)

인증/권한:
├─ LDAP Plugin (LDAP 인증)
├─ Role-based Authorization (역할 기반 권한)

알림:
├─ Email Extension (이메일)
├─ Slack Plugin (Slack)
├─ PagerDuty Plugin (PagerDuty)

기타:
├─ Build Timeout (빌드 타임아웃)
├─ Log Parser Plugin (로그 분석)
├─ Green Balls (파란 공 표시)
```

---

## 🔐 Credentials 설정

### 1. Git Credentials

```
Jenkins Home → Manage Credentials → System → Global credentials

Add Credentials:
├─ Kind: Username with password
├─ Username: git-user
├─ Password: git-password
├─ ID: git-credentials
└─ Description: Git Repository Credentials
```

### 2. Docker Registry Credentials

```
Add Credentials:
├─ Kind: Username with password
├─ Username: docker-user
├─ Password: docker-password
├─ ID: docker-registry-credentials
└─ Description: Docker Registry Login
```

### 3. SSH Key

```
Add Credentials:
├─ Kind: SSH Username with private key
├─ Username: deploy-user
├─ Private Key: (파일 선택 또는 직접 입력)
├─ ID: deploy-ssh-key
└─ Description: Deploy Server SSH Key
```

### 4. API Token / Secret

```
Add Credentials:
├─ Kind: Secret text
├─ Secret: (토큰/시크릿 입력)
├─ ID: sonar-token
└─ Description: SonarQube API Token
```

### 5. Jenkins CLI에서 설정

```bash
# Credentials ID로 사용
pipeline {
    environment {
        GIT_CRED = credentials('git-credentials')
        DOCKER_CRED = credentials('docker-registry-credentials')
        SSH_KEY = credentials('deploy-ssh-key')
    }
    
    stages {
        stage('Example') {
            steps {
                sh '''
                    echo $GIT_CRED_PSW | git credential approve
                    docker login -u $DOCKER_CRED_USR -p $DOCKER_CRED_PSW
                '''
            }
        }
    }
}
```

---

## 🛠️ Job 생성 방법

### 1. Freestyle Job

```
New Item → Freestyle Job

설정:
├─ Source Code Management
│  ├─ Git
│  ├─ Repository URL: https://github.com/your-org/your-repo.git
│  └─ Credentials: git-credentials
├─ Build Triggers
│  └─ GitHub hook trigger for GITScm polling
├─ Build Steps
│  ├─ Execute shell: mvn clean package
│  └─ Execute shell: docker build -t image:v1.0 .
└─ Post-build Actions
   └─ Archive the artifacts: target/*.jar

Save → Build Now
```

### 2. Pipeline Job

```
New Item → Pipeline

설정:
├─ Definition: Pipeline script from SCM
├─ SCM: Git
├─ Repository URL: https://github.com/your-org/your-repo.git
├─ Credentials: git-credentials
├─ Script Path: Jenkinsfile
└─ Save

또는

Definition: Pipeline script
├─ Script: (Jenkinsfile 코드 붙여넣기)
└─ Save
```

### 3. Multi-branch Pipeline

```
New Item → Multibranch Pipeline

설정:
├─ Branch Sources
│  ├─ Git
│  ├─ Project Repository: https://github.com/your-org/your-repo.git
│  ├─ Credentials: git-credentials
│  └─ Behaviors: Discover branches, Discover pull requests
├─ Scan Repository Triggers
│  └─ Periodically: 1 hour
└─ Save

자동으로 모든 브랜치/PR에 대해 Jenkinsfile 감지 및 실행
```

---

## 📊 Job 모니터링 및 관리

### Console Output 확인

```bash
# Jenkins CLI로 로그 확인
java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar \
  -s http://localhost:8080 \
  console my-job 100  # 마지막 100줄

# 또는 웹 UI
http://localhost:8080/job/my-job/100/console
```

### Build 트리거

```groovy
// Webhook (GitHub)
pipeline {
    triggers {
        githubPush()
    }
}

// Poll SCM
pipeline {
    triggers {
        pollSCM('H/15 * * * *')  // 15분마다
    }
}

// Timer
pipeline {
    triggers {
        cron('0 2 * * *')  // 매일 02:00
    }
}

// Upstream job 완료
pipeline {
    triggers {
        upstream(upstreamProjects: 'upstream-job', threshold: hudson.model.Result.SUCCESS)
    }
}
```

### Build Parameters 활용

```groovy
pipeline {
    parameters {
        string(name: 'BUILD_VERSION', defaultValue: '1.0.0')
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'staging', 'prod'])
        booleanParam(name: 'FORCE_DEPLOY', defaultValue: false)
    }
    
    stages {
        stage('Deploy') {
            steps {
                sh '''
                    echo "Version: ${BUILD_VERSION}"
                    echo "Environment: ${DEPLOY_ENV}"
                    if [ "${FORCE_DEPLOY}" = "true" ]; then
                        echo "Force deploying..."
                    fi
                '''
            }
        }
    }
}
```

---

## 🔍 디버깅 및 문제 해결

### Jenkins 로그 확인

```bash
# 컨테이너 로그
docker logs -f cicd-jenkins

# Jenkins 홈 디렉토리 로그
docker exec cicd-jenkins cat /var/jenkins_home/logs/*.log

# 특정 Job 로그
docker exec cicd-jenkins cat /var/jenkins_home/jobs/my-job/builds/1/log
```

### Common Issues

```bash
# 1. Out of Memory
# docker-compose.yml에 JVM 옵션 추가
environment:
  JAVA_OPTS: "-Xmx2048m -Xms1024m"

# 2. Plugins conflict
# Plugin Manager에서 충돌하는 플러그인 비활성화 또는 제거
Manage Jenkins → Manage Plugins → Installed → Uncheck → Restart

# 3. Job 초기화
rm -rf /var/jenkins_home/jobs/my-job
docker restart cicd-jenkins

# 4. Configuration reload
Manage Jenkins → System Configuration → Reload Configuration from Disk
```

---

## 🚀 배포 스크립트 예제

### Maven 기반 배포

```groovy
pipeline {
    agent any
    
    environment {
        NEXUS_URL = "https://nexus.example.com"
        NEXUS_CREDS = credentials('nexus-credentials')
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    mvn deploy \
                        -Drevision=1.0.0 \
                        -Dchangelist=-SNAPSHOT \
                        -DaltDeploymentRepository="releases::default::${NEXUS_URL}/repository/maven-releases"
                '''
            }
        }
    }
}
```

### Docker 기반 배포

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = "registry.example.com"
        DOCKER_CRED = credentials('docker-registry-credentials')
        IMAGE_TAG = "v${BUILD_NUMBER}"
    }
    
    stages {
        stage('Build Image') {
            steps {
                script {
                    docker.build("${DOCKER_REGISTRY}/app:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Push Image') {
            steps {
                script {
                    docker.image("${DOCKER_REGISTRY}/app:${IMAGE_TAG}").push()
                    docker.image("${DOCKER_REGISTRY}/app:${IMAGE_TAG}").push("latest")
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    kubectl set image deployment/app \
                        app=${DOCKER_REGISTRY}/app:${IMAGE_TAG} \
                        -n production
                '''
            }
        }
    }
}
```

### Kubernetes 배포

```groovy
pipeline {
    agent any
    
    stages {
        stage('Deploy') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8s-credentials') {
                        sh '''
                            kubectl apply -f k8s/deployment.yaml
                            kubectl rollout status deployment/app -n production
                        '''
                    }
                }
            }
        }
    }
}
```

---

## 📈 메트릭 및 모니터링

### Build Status Page

```
http://localhost:8080/jobs.json        # JSON 형식
http://localhost:8080/job/my-job/api/json
http://localhost:8080/api/json?tree=jobs[name,url,color]
```

### Metrics Plugin

```groovy
pipeline {
    post {
        always {
            // JUnit 테스트 결과
            junit 'target/surefire-reports/*.xml'
            
            // Code Coverage
            publishHTML([
                reportDir: 'target/site/jacoco',
                reportFiles: 'index.html',
                reportName: 'JaCoCo Report'
            ])
            
            // Performance
            perfReport(
                sourceDir: 'target/performance',
                reportFiles: '*.xml'
            )
        }
    }
}
```

---

## 🎯 빠른 명령어 모음

### Jenkins CLI 주요 명령

```bash
# Build 시작
java -jar cli.jar -s http://localhost:8080 build my-job

# Job 정보
java -jar cli.jar -s http://localhost:8080 get-job my-job

# Job 설정 다운로드
java -jar cli.jar -s http://localhost:8080 get-job my-job > job-config.xml

# Job 설정 업로드
java -jar cli.jar -s http://localhost:8080 create-job my-job < job-config.xml

# Job 목록
java -jar cli.jar -s http://localhost:8080 list-jobs

# Console 출력
java -jar cli.jar -s http://localhost:8080 console my-job 100

# Jenkins 재시작
java -jar cli.jar -s http://localhost:8080 restart

# 모든 Job 비활성화
java -jar cli.jar -s http://localhost:8080 disable-job my-job
```

### Groovy 스크립트 예제

```groovy
// Jenkins 시스템 정보
def version = Jenkins.getInstance().VERSION
def jenkins = Jenkins.getInstance()
def items = jenkins.getAllItems()

// Job 생성
import jenkins.model.Jenkins
def job = new FreeStyleProject(Jenkins.getInstance(), "new-job")

// Credentials 접근
import com.cloudbees.plugins.credentials.CredentialsProvider
def creds = CredentialsProvider.lookupCredentials(StandardUsernamePasswordCredentials)

// System 메시지 설정
Jenkins.getInstance().setSystemMessage("Jenkins is ready!")
```

---

## ⚠️ 백업 및 복구

### Jenkins 홈 디렉토리 백업

```bash
# 백업
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz \
  -C /var/jenkins_home .

# 복구
tar -xzf jenkins-backup-20240515.tar.gz \
  -C /var/jenkins_home
docker restart cicd-jenkins
```

### Docker Volume 백업

```bash
# 백업
docker run --rm -v jenkins_home:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/jenkins-backup.tar.gz -C /data .

# 복구
docker run --rm -v jenkins_home:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/jenkins-backup.tar.gz -C /data
```

---

## 📱 모바일/UI 팁

### Dark Mode 활성화

```
Jenkins → Manage Jenkins → System Configuration → Look and Feel
→ UI Theme: Dark theme
```

### Email 알림 설정

```
Manage Jenkins → System Configuration → Extended E-mail Notification

SMTP Server: smtp.gmail.com
SMTP Port: 465
Use SMTP Authentication: checked
User Name: your-email@gmail.com
Password: app-password
Use SSL: checked
SMTP TLS Port: 465
```

---

**Jenkins를 5분 안에 완벽하게 설정할 수 있습니다!** 🚀
