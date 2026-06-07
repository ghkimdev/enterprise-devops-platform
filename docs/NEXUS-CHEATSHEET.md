# Nexus 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```bash
# docker-compose.yml에 추가
nexus:
  build:
    context: ./nexus
    dockerfile: docker/Dockerfile
  hostname: nexus.example.com
  container_name: cicd-nexus
  restart: unless-stopped
  environment:
    INSTALL4J_ADD_VM_PARAMS: "-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m"
  ports:
    - "8081:8081"
  volumes:
    - nexus_data:/nexus-data
  networks:
    - cicd-net
  depends_on:
    - ldap

# 실행
docker-compose up -d nexus

# 초기 비밀번호 확인 (2-3분 대기)
docker exec cicd-nexus cat /nexus-data/admin.password

# 브라우저에서 접속
http://localhost:8081
# 계정: admin / <위의 비밀번호>
```

---

## 📋 초기 설정

### 1. 관리자 비밀번호 변경

```
로그인 → 우측 상단 "admin" → Change password

New password: AdminPass123
Confirm password: AdminPass123
```

### 2. LDAP 연동

```
Settings (좌측 메뉴) → Security → Realms

LDAP 추가:
├─ Name: LDAP
├─ Protocol: ldap
├─ Hostname: ldap
├─ Port: 389
├─ Search Base: dc=example,dc=com
├─ Authentication Method: Simple Authentication
├─ Username or DN: cn=admin,dc=example,dc=com
├─ Password: AdminPass123
├─ User Member Of Attribute: memberOf
├─ User Object Class: inetOrgPerson
└─ Save

Active Realms에 "LDAP" 추가
```

### 3. 저장소 설정

```
Repository → Repositories

Maven 저장소 생성:
├─ Type: maven2
├─ Format: Maven 2
├─ Name: maven-releases
├─ Blob Store: default
└─ Create Repository

또는

Name: maven-snapshots
Version Policy: Snapshot
Deployment Policy: Allow redeploy
```

---

## 📦 Maven 통합

### 1. Maven Settings 설정

```xml
<!-- ~/.m2/settings.xml -->
<settings>
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>nexus-admin</username>
      <password>NexusAdminPass123</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>nexus-admin</username>
      <password>NexusAdminPass123</password>
    </server>
  </servers>
  
  <mirrors>
    <mirror>
      <id>nexus-central</id>
      <mirrorOf>central</mirrorOf>
      <url>https://nexus.example.com/repository/maven-central/</url>
    </mirror>
    <mirror>
      <id>nexus-public</id>
      <mirrorOf>*</mirrorOf>
      <url>https://nexus.example.com/repository/maven-public/</url>
    </mirror>
  </mirrors>
  
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>nexus-releases</id>
          <url>https://nexus.example.com/repository/maven-releases/</url>
          <releases>
            <enabled>true</enabled>
            <checksumPolicy>warn</checksumPolicy>
          </releases>
          <snapshots>
            <enabled>false</enabled>
          </snapshots>
        </repository>
        <repository>
          <id>nexus-snapshots</id>
          <url>https://nexus.example.com/repository/maven-snapshots/</url>
          <releases>
            <enabled>false</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>
  
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

### 2. POM 설정

```xml
<!-- pom.xml -->
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>my-app</artifactId>
  <version>1.0.0</version>
  
  <distributionManagement>
    <repository>
      <id>nexus-releases</id>
      <name>Nexus Release Repository</name>
      <url>https://nexus.example.com/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
      <id>nexus-snapshots</id>
      <name>Nexus Snapshot Repository</name>
      <url>https://nexus.example.com/repository/maven-snapshots/</url>
    </snapshotRepository>
  </distributionManagement>
  
  <dependencies>
    <!-- 의존성 정의 -->
  </dependencies>
  
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-deploy-plugin</artifactId>
        <version>2.8.2</version>
      </plugin>
    </plugins>
  </build>
</project>
```

### 3. 아티팩트 배포

```bash
# SNAPSHOT 배포 (개발 버전)
mvn clean deploy -DskipTests

# RELEASE 배포 (정식 버전)
mvn clean package -DskipTests
mvn deploy:deploy-file \
  -DgroupId=com.example \
  -DartifactId=my-app \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -Dfile=target/my-app-1.0.0.jar \
  -Durl=https://nexus.example.com/repository/maven-releases/ \
  -DrepositoryId=nexus-releases
```

---

## 🐳 Docker 저장소

### 1. Docker Registry 생성

```
Repositories → Create repository

Type: Docker (hosted)
Name: docker-releases
Blob Store: default
Cleanup policies: (선택사항)
Repository Connectors: (Docker API/Registry)
```

### 2. Docker 로그인

```bash
# Nexus에 로그인
docker login -u nexus-admin -p NexusAdminPass123 \
  nexus.example.com:8082

# 또는 /etc/docker/daemon.json 설정
{
  "insecure-registries": ["nexus.example.com:8082"],
  "auths": {
    "nexus.example.com:8082": {
      "auth": "bmV4dXMtYWRtaW46TmV4dXNBZG1pblBhc3MxMjM="
    }
  }
}

# 재시작
sudo systemctl restart docker
```

### 3. Docker 이미지 푸시

```bash
# 이미지 빌드
docker build -t my-app:1.0.0 .

# 태그 추가
docker tag my-app:1.0.0 \
  nexus.example.com:8082/my-app:1.0.0

# 푸시
docker push nexus.example.com:8082/my-app:1.0.0

# 또는 자동화
#!/bin/bash
REGISTRY="nexus.example.com:8082"
IMAGE="my-app"
VERSION="1.0.0"

docker build -t $IMAGE:$VERSION .
docker tag $IMAGE:$VERSION $REGISTRY/$IMAGE:$VERSION
docker tag $IMAGE:$VERSION $REGISTRY/$IMAGE:latest
docker push $REGISTRY/$IMAGE:$VERSION
docker push $REGISTRY/$IMAGE:latest
```

### 4. Docker 이미지 풀

```bash
docker pull nexus.example.com:8082/my-app:1.0.0
docker run -it nexus.example.com:8082/my-app:1.0.0
```

---

## 🔍 저장소 관리

### 1. 저장소 생성

```
Repositories → Create repository

Raw 저장소 (일반 파일):
├─ Name: raw-releases
├─ Format: Raw
├─ Type: Hosted
└─ Create

NPM 저장소:
├─ Name: npm-releases
├─ Format: npm
├─ Type: Hosted
└─ Create

PyPI 저장소:
├─ Name: pypi-releases
├─ Format: PyPI
├─ Type: Hosted
└─ Create
```

### 2. 저장소 권한 설정

```
Security → Privileges → New Privilege

Privilege 생성:
├─ Name: read-releases
├─ Description: Read access to releases
├─ Type: Repository View
├─ Repository: maven-releases
└─ Create

Role 생성:
├─ Name: release-reader
├─ Add privilege: read-releases
└─ Create

User에 Role 할당:
├─ Users → Select user
├─ Add roles: release-reader
└─ Save
```

---

## 📝 아티팩트 관리

### 1. 업로드

```bash
# Curl로 업로드
curl -v -u nexus-admin:NexusAdminPass123 \
  --upload-file my-app-1.0.0.jar \
  https://nexus.example.com/repository/maven-releases/com/example/my-app/1.0.0/my-app-1.0.0.jar

# 또는 UI
Upload → Select file → Select repository → Deploy
```

### 2. 검색

```
Browse → Select repository → 파일 탐색

또는 UI 검색:
Search → Keyword 입력 → 검색
```

### 3. 삭제

```bash
# UI에서
Browse → Select repository → 파일 선택 → Delete

# 또는 API
curl -X DELETE \
  -u nexus-admin:NexusAdminPass123 \
  https://nexus.example.com/repository/maven-releases/com/example/my-app/1.0.0/my-app-1.0.0.jar
```

---

## 🔐 보안 정책

### 1. 익명 접근 제어

```
Security → Anonymous Access

Enable anonymous access: ON/OFF
```

### 2. CORS 설정

```
Security → Realms → CORS

Allow requests from: *
Allow methods: GET, PUT, POST, DELETE, OPTIONS
```

### 3. 저장소 보호

```
Repository → Edit

Deployment policy: 
├─ Allow redeploy (SNAPSHOT만)
├─ Disable redeploy (RELEASE는 불가)
└─ Read-only
```

---

## 📊 모니터링 및 정리

### 1. 저장소 정리 (Cleanup Policy)

```
Repository → Edit

Cleanup policies:
├─ Delete artifacts with no downloads in: 30 days
├─ Delete pre-release: enabled
└─ Save
```

### 2. 디스크 공간 관리

```
System → Storage

각 저장소의 크기 확인
- maven-releases: 500MB
- maven-snapshots: 200MB
- docker-releases: 1GB

필요시 오래된 버전 삭제
```

### 3. 로그 확인

```bash
# 컨테이너 로그
docker logs -f cicd-nexus

# Nexus 애플리케이션 로그
docker exec cicd-nexus tail -f /nexus-data/log/nexus.log

# 접속 로그
docker exec cicd-nexus tail -f /nexus-data/log/access.log
```

---

## 📦 NPM 패키지 배포

### 1. NPM Registry 설정

```bash
# ~/.npmrc
registry=https://nexus.example.com/repository/npm-releases/
_auth=<base64 encoded username:password>
always-auth=true
email=user@example.com
```

### 2. 패키지 배포

```bash
# package.json
{
  "name": "@example/my-package",
  "version": "1.0.0",
  "publishConfig": {
    "registry": "https://nexus.example.com/repository/npm-releases/"
  }
}

# 배포
npm publish

# 또는 인증 토큰
npm config set //nexus.example.com/repository/npm-releases/:_auth=<TOKEN>
npm publish
```

### 3. 패키지 설치

```bash
npm install @example/my-package

# 또는 .npmrc에서
@example:registry=https://nexus.example.com/repository/npm-releases/
```

---

## 🐍 Python/PyPI 패키지 배포

### 1. PyPI Registry 설정

```bash
# ~/.pypirc
[distutils]
index-servers =
    nexus

[nexus]
repository: https://nexus.example.com/repository/pypi-releases/
username: nexus-admin
password: NexusAdminPass123
```

### 2. 패키지 배포

```bash
# setup.py
from setuptools import setup

setup(
    name='my-package',
    version='1.0.0',
    packages=['my_package'],
    author='Your Name',
    author_email='you@example.com',
)

# 배포
python setup.py sdist bdist_wheel
twine upload -r nexus dist/*
```

### 3. 패키지 설치

```bash
pip install --index-url https://nexus.example.com/repository/pypi-releases/ \
  my-package
```

---

## 🔌 API 사용

### 1. REST API 활용

```bash
# 저장소 목록
curl -u nexus-admin:NexusAdminPass123 \
  https://nexus.example.com/service/rest/v1/repositories

# 아티팩트 검색
curl -u nexus-admin:NexusAdminPass123 \
  "https://nexus.example.com/service/rest/v1/search?repository=maven-releases&name=my-app"

# 아티팩트 정보
curl -u nexus-admin:NexusAdminPass123 \
  "https://nexus.example.com/service/rest/v1/search/assets?repository=maven-releases&name=my-app-1.0.0.jar"

# 아티팩트 다운로드
curl -u nexus-admin:NexusAdminPass123 \
  -O https://nexus.example.com/repository/maven-releases/com/example/my-app/1.0.0/my-app-1.0.0.jar
```

### 2. Groovy Script (Advanced)

```groovy
// Nexus에서 스크립트 실행
// System → Tasks → Create task → Execute script

def session = security.javaSession

// 저장소 확인
repository.repositoryManager.browse().each { repo ->
  println "Repository: ${repo.name}"
}

// 아티팩트 삭제
def repo = repository.repositoryManager.get('maven-releases')
repo.facet(StorageFacet).deleteComponent(component)
```

---

## 🎯 자동화 스크립트

### Maven 자동 배포

```bash
#!/bin/bash

VERSION=$1
NEXUS_URL="https://nexus.example.com"
NEXUS_REPO="maven-releases"
NEXUS_USER="nexus-admin"
NEXUS_PASS="NexusAdminPass123"

# 빌드
mvn clean package -DskipTests -Drevision=$VERSION

# 배포
mvn deploy \
  -Drevision=$VERSION \
  -DaltDeploymentRepository="$NEXUS_REPO::default::$NEXUS_URL/repository/$NEXUS_REPO"

echo "✓ Version $VERSION deployed to Nexus"
```

### Docker 이미지 배포

```bash
#!/bin/bash

APP_NAME="my-app"
VERSION=$1
REGISTRY="nexus.example.com:8082"
NEXUS_USER="nexus-admin"
NEXUS_PASS="NexusAdminPass123"

# 로그인
echo "$NEXUS_PASS" | docker login -u "$NEXUS_USER" --password-stdin $REGISTRY

# 이미지 빌드 및 푸시
docker build -t $REGISTRY/$APP_NAME:$VERSION .
docker push $REGISTRY/$APP_NAME:$VERSION
docker tag $REGISTRY/$APP_NAME:$VERSION $REGISTRY/$APP_NAME:latest
docker push $REGISTRY/$APP_NAME:latest

echo "✓ Docker image $VERSION pushed to Nexus"
```

### Jenkins Pipeline 통합

```groovy
pipeline {
    environment {
        NEXUS_URL = "https://nexus.example.com"
        NEXUS_CREDS = credentials('nexus-credentials')
    }
    
    stages {
        stage('Deploy to Nexus') {
            steps {
                sh '''
                    mvn deploy \
                        -Drevision=${BUILD_VERSION} \
                        -DaltDeploymentRepository="releases::default::${NEXUS_URL}/repository/maven-releases"
                '''
            }
        }
    }
}
```

---

## ⚠️ 트러블슈팅

```
문제 1: 로그인 실패
→ LDAP 연동 확인
→ 사용자 그룹 확인
→ 비밀번호 정확성 확인

문제 2: 아티팩트 배포 실패
→ 저장소 권한 확인
→ 배포 정책 확인 (SNAPSHOT/RELEASE)
→ Nexus 디스크 공간 확인

문제 3: Docker 푸시 실패
→ Docker 로그인 확인
→ Registry URL 정확성 확인
→ 포트 개방 확인

문제 4: 느린 다운로드
→ 네트워크 대역폭 확인
→ Nexus 메모리 부족 확인
→ 저장소 최적화 실행
```

---

## 🎯 빠른 참조

```bash
# Maven 배포
mvn deploy

# Docker 이미지 푸시
docker push nexus.example.com:8082/my-app:1.0.0

# 아티팩트 검색
curl -u admin https://nexus.example.com/service/rest/v1/search?name=my-app

# 아티팩트 다운로드
curl -u admin -O https://nexus.example.com/repository/maven-releases/...

# NPM 패키지 배포
npm publish

# Python 패키지 배포
twine upload dist/*

# 저장소 정리
# UI에서 "Cleanup policies" 실행
```

**Nexus를 5분 안에 완벽하게 설정할 수 있습니다!** 🚀
