# SVN (Subversion) 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```bash
# docker-compose.yml에 추가
svn:
  build:
    context: ./svn
    dockerfile: docker/Dockerfile
  hostname: svn.example.com
  container_name: cicd-svn
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./repos:/var/svn/repos
    - ./svn/svn-authz.conf:/etc/apache2/svn-authz.conf
    - ./svn/svn.conf:/etc/apache2/conf-available/svn.conf
  networks:
    - cicd-net
  depends_on:
    - ldap

# 실행
docker-compose up -d svn

# 저장소 생성 (1분 대기 후)
docker exec cicd-svn svnadmin create /var/svn/repos/project1
docker exec cicd-svn chown -R www-data:www-data /var/svn/repos

# 접속
http://localhost/svn
# LDAP 계정으로 로그인
```

---

## 📋 SVN 저장소 구조 (Best Practice)

```
project1/
├── trunk/           # 주 개발 브랜치
│   ├── src/
│   ├── pom.xml
│   └── README.md
├── branches/        # 기능/버그 브랜치
│   ├── feature-auth/
│   └── bugfix-123/
└── tags/            # 릴리스 태그
    ├── v1.0.0/
    └── v1.0.1/
```

---

## 📝 기본 명령어 Cheat Sheet

### 1. 저장소 생성 및 초기화

```bash
# 저장소 생성
svnadmin create /var/svn/repos/project1

# 저장소 확인
ls -la /var/svn/repos/project1

# 초기 폴더 구조 생성
svn mkdir -m "Initial trunk, branches, tags directories" \
  file:///var/svn/repos/project1/trunk \
  file:///var/svn/repos/project1/branches \
  file:///var/svn/repos/project1/tags

# 또는 로컬에서 먼저 생성 후 import
mkdir -p svn-project/{trunk,branches,tags}
svn import svn-project file:///var/svn/repos/project1 \
  -m "Initial project structure"
```

### 2. 저장소 체크아웃 (클론)

```bash
# 전체 저장소 체크아웃
svn checkout http://svn.example.com/svn/project1 project1

# Trunk만 체크아웃 (권장)
svn checkout http://svn.example.com/svn/project1/trunk project1

# 특정 버전 체크아웃
svn checkout http://svn.example.com/svn/project1 \
  -r 100 project1

# 특정 태그 체크아웃
svn checkout http://svn.example.com/svn/project1/tags/v1.0.0 project1-v1.0.0
```

### 3. 코드 커밋

```bash
# 변경사항 확인
svn status

# 파일 추가
svn add new-file.txt

# 파일 삭제
svn delete old-file.txt

# 커밋
svn commit -m "feat: add new authentication feature"

# 또는 상세 메시지
svn commit -F commit-message.txt

# 변경사항 보기
svn diff
svn diff file.txt
```

### 4. 브랜칭

```bash
# Trunk에서 Feature 브랜치 생성
svn copy http://svn.example.com/svn/project1/trunk \
  http://svn.example.com/svn/project1/branches/feature-auth \
  -m "Create feature-auth branch"

# 로컬에서 브랜치 작업
svn switch http://svn.example.com/svn/project1/branches/feature-auth

# Trunk로 돌아가기
svn switch http://svn.example.com/svn/project1/trunk

# 브랜치 확인
svn list http://svn.example.com/svn/project1/branches
```

### 5. Merge (병합)

```bash
# Trunk에서 브랜치 생성
cd project1-trunk

# 브랜치에서 수정 후 Trunk에 병합하기
# 1. 브랜치 업데이트
svn update

# 2. Merge
svn merge http://svn.example.com/svn/project1/branches/feature-auth

# 3. 변경사항 확인 후 커밋
svn commit -m "Merge feature-auth branch to trunk"
```

### 6. 태그 생성 (릴리스)

```bash
# Trunk에서 태그 생성 (스냅샷)
svn copy http://svn.example.com/svn/project1/trunk \
  http://svn.example.com/svn/project1/tags/v1.0.0 \
  -m "Tag release v1.0.0"

# 태그 확인
svn list http://svn.example.com/svn/project1/tags

# 태그에서 체크아웃
svn checkout http://svn.example.com/svn/project1/tags/v1.0.0 \
  project1-v1.0.0
```

### 7. 업데이트

```bash
# 최신 버전으로 업데이트
svn update

# 특정 파일만 업데이트
svn update specific-file.txt

# 특정 리비전으로 업데이트
svn update -r 100

# 리비전 확인
svn log --limit 10

# 특정 파일의 히스토리
svn log src/main.py
```

---

## 🔍 히스토리 및 추적

### 1. 로그 확인

```bash
# 전체 커밋 로그
svn log

# 마지막 10개 커밋
svn log --limit 10

# 상세 정보 포함
svn log -v

# 특정 파일의 변경 이력
svn log src/main.py

# 특정 날짜 이후 커밋
svn log -r {2024-01-01}:HEAD

# 특정 리비전 범위
svn log -r 100:200

# 특정 사용자의 커밋
svn log | grep "john-doe"
```

### 2. 변경사항 추적

```bash
# 현재 상태 확인
svn status

# 상세 정보
svn status -v

# 특정 파일 변경사항
svn diff src/main.py

# 리비전 간 차이
svn diff -r 100:120 src/main.py

# 특정 리비전 확인
svn cat -r 100 src/main.py

# 파일 책임 추적
svn blame src/main.py
```

### 3. 변경사항 추적 (Blame)

```bash
# 파일의 각 줄이 누가 언제 수정했는지 확인
svn blame src/main.py

# 특정 리비전에서의 상태
svn blame -r 100 src/main.py

# HTML 형식으로 출력
svn blame --xml src/main.py > blame.xml
```

---

## 🔐 권한 관리

### SVN Authorization (authz.conf)

```apache
# /etc/apache2/svn-authz.conf

[groups]
developers = john-doe, jane-doe, svn-developer
admins = svn-admin
ci = build, deploy

[/]
@admins = rw
@developers = rw
@ci = r

[/tags]
@admins = rw
@developers = r
@ci = r

[/branches]
@developers = rw
@ci = r

[/release]
@admins = rw
@ci = rw
```

### LDAP 기반 권한 설정

```apache
# /etc/apache2/svn.conf

<Location /svn>
  DAV svn
  SVNPath /var/svn/repos
  
  # LDAP 인증
  AuthType Basic
  AuthName "SVN Repository"
  AuthBasicProvider ldap
  AuthLDAPURL ldap://ldap:389/ou=users,dc=example,dc=com?uid
  AuthLDAPGroupAttribute memberUid
  AuthLDAPGroupAttributeIsDN off
  
  # 권한 파일
  AuthzSVNAccessFile /etc/apache2/svn-authz.conf
  
  Require valid-user
</Location>
```

---

## 🚀 Jenkins와 통합

### 1. Jenkins에서 SVN 사용

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'SubversionSCM',
                    locations: [[
                        local: '.',
                        remote: 'http://svn.example.com/svn/project1/trunk'
                    ]],
                    workspaceUpdater: [$class: 'UpdateUpdater']
                ])
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }
}
```

### 2. SVN Hook으로 Jenkins 트리거

```bash
#!/bin/bash
# /var/svn/repos/project1/hooks/post-commit

REPOS="$1"
REV="$2"

# Jenkins 트리거
curl -X POST \
  http://jenkins.example.com:8080/job/my-job/buildWithParameters \
  -u jenkins-user:jenkins-password \
  -F "SVN_REVISION=$REV"
```

---

## 🔄 Git과 비교

### SVN vs Git (Cheat Sheet)

```
작업                    Git                          SVN
────────────────────────────────────────────────────────────
저장소 초기화           git init                     svnadmin create
코드 가져오기           git clone                    svn checkout
브랜치 생성             git branch                   svn copy
브랜치 변경             git checkout                 svn switch
병합                    git merge                    svn merge
커밋                    git commit                   svn commit
태그                    git tag                      svn copy (to tags/)
로그                    git log                      svn log
차이                    git diff                     svn diff
상태                    git status                   svn status
리버트                  git revert                   svn revert
히스토리                git reflog                   svn log --verbose
```

---

## 🛠️ 자주 사용하는 스크립트

### 저장소 백업

```bash
#!/bin/bash

REPO_PATH="/var/svn/repos/project1"
BACKUP_DIR="/backup/svn"
DATE=$(date +%Y%m%d)

# 전체 덤프
svnadmin dump $REPO_PATH > $BACKUP_DIR/project1-$DATE.dump

# 압축
gzip $BACKUP_DIR/project1-$DATE.dump

# 오래된 백업 삭제
find $BACKUP_DIR -name "*.dump.gz" -mtime +30 -delete

echo "✓ SVN backup completed: project1-$DATE.dump.gz"
```

### 저장소 복구

```bash
#!/bin/bash

BACKUP_FILE="project1-20240515.dump.gz"
REPO_PATH="/var/svn/repos/project1-restored"

# 저장소 생성
svnadmin create $REPO_PATH

# 백업 복구
gunzip -c $BACKUP_FILE | svnadmin load $REPO_PATH

# 권한 설정
chown -R www-data:www-data $REPO_PATH
chmod 750 $REPO_PATH

echo "✓ SVN repository restored to $REPO_PATH"
```

### 리비전 정리 (Garbage Collection)

```bash
#!/bin/bash

REPO_PATH="/var/svn/repos/project1"

# 트랜잭션 정리
svnadmin list-unused-dblogs $REPO_PATH | \
  xargs rm -f

# 데이터베이스 정리
svnadmin pack $REPO_PATH

echo "✓ SVN repository cleaned"
```

### 대량 import

```bash
#!/bin/bash

# 프로젝트 구조 생성
for project in project1 project2 project3; do
  svn mkdir -m "Create $project structure" \
    file:///var/svn/repos/$project/trunk \
    file:///var/svn/repos/$project/branches \
    file:///var/svn/repos/$project/tags
done

echo "✓ All projects created"
```

---

## ⚠️ 일반적인 문제 해결

### 1. 충돌 해결 (Conflicts)

```bash
# 충돌 확인
svn status

# 파일 상태 확인
svn status | grep "C"

# 충돌 파일 확인
cat conflicted-file.txt
# <<<<<<< yours
# your changes
# =======
# their changes
# >>>>>>> theirs

# 해결 방법 1: 내 버전 선택
svn resolve --accept=mine conflicted-file.txt

# 해결 방법 2: 상대방 버전 선택
svn resolve --accept=theirs conflicted-file.txt

# 해결 방법 3: 수동으로 편집 후
vim conflicted-file.txt
svn resolve conflicted-file.txt

# 커밋
svn commit -m "Resolve merge conflict"
```

### 2. 실수로 커밋한 파일 삭제

```bash
# 방법 1: 최신 버전에서 삭제
svn delete secret-file.txt
svn commit -m "Remove accidental secret file"

# 방법 2: 특정 리비전 되돌리기
svn merge -c -100 .  # 리비전 100 되돌리기
svn commit -m "Revert secret file commit"
```

### 3. 브랜치 업데이트

```bash
# 브랜치에서 trunk의 최신 변경사항 받기
svn switch http://svn.example.com/svn/project1/branches/feature-auth
svn merge http://svn.example.com/svn/project1/trunk
svn commit -m "Update feature branch with trunk changes"
```

### 4. 권한 문제

```bash
# 권한 확인
svn list http://svn.example.com/svn/project1 \
  --username=john-doe --password=password

# LDAP 권한 확인
sudo grep john-doe /etc/apache2/svn-authz.conf

# 재시작 후 확인
sudo systemctl restart apache2
```

---

## 📊 모니터링 및 유지보수

### 저장소 정보

```bash
# 저장소 통계
svnadmin info /var/svn/repos/project1

# 저장소 크기
du -sh /var/svn/repos/project1

# 최신 리비전
svnlook youngest /var/svn/repos/project1

# 특정 리비전 상세 정보
svnlook info -r 100 /var/svn/repos/project1
```

### 성능 최적화

```bash
# 데이터베이스 최적화
svnadmin pack /var/svn/repos/project1

# 트랜잭션 정리
svnadmin list-unused-dblogs /var/svn/repos/project1 | \
  xargs rm -f

# 리포지토리 검사
svnadmin verify /var/svn/repos/project1
```

---

## 🎯 빠른 참조 (Most Used Commands)

```bash
# 체크아웃
svn checkout http://svn.example.com/svn/project1/trunk

# 상태 확인
svn status

# 커밋
svn commit -m "commit message"

# 업데이트
svn update

# 로그 확인
svn log --limit 10

# 브랜치 생성
svn copy http://...trunk http://...branches/feature-name -m "Create branch"

# 브랜치 전환
svn switch http://...branches/feature-name

# 병합
svn merge http://...trunk

# 태그 생성
svn copy http://...trunk http://...tags/v1.0.0 -m "Tag v1.0.0"

# 충돌 해결
svn resolve --accept=mine conflicted-file.txt

# 되돌리기
svn revert file.txt
```

---

## 📱 Web UI (ViewVC)

```bash
# ViewVC 설치 및 설정
sudo apt-get install viewvc

# 설정 파일 편집
sudo vim /etc/viewvc/viewvc.conf

# 재시작
sudo systemctl restart apache2

# 접속
http://svn.example.com/viewvc
```

---

## 🚀 마이그레이션 (SVN → Git)

```bash
# Git에서 SVN 저장소 클론
git svn clone -s http://svn.example.com/svn/project1 project1-git

# SVN 태그를 Git 태그로 변환
cd project1-git
git for-each-ref --format="delete %(refname)" refs/remotes/tags | \
  git update-ref --stdin

# GitHub에 푸시
git remote add origin https://github.com/your-org/project1.git
git push -u origin main --all --tags
```

**SVN을 5분 안에 완벽하게 구축할 수 있습니다!** 🚀
