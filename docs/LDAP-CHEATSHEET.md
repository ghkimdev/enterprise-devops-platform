# LDAP 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```bash
# docker-compose.yml에 추가
ldap:
  container_name: cicd-ldap
  image: osixia/openldap:latest
  environment:
    LDAP_ORGANISATION: "Example Corp"
    LDAP_DOMAIN: "example.com"
    LDAP_ADMIN_PASSWORD: "AdminPass123"
    LDAP_TLS: "true"
  volumes:
    - ldap_data:/var/lib/ldap
    - ldap_conf:/container/service/slapd
    - ./ldap/init-enhanced.ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom/init.ldif
  ports:
    - "389:389"
    - "636:636"
  networks:
    - cicd-net

# 실행
docker-compose up -d ldap

# 확인 (30초 대기)
sleep 30
ldapsearch -H ldap://localhost:389 -x -D "cn=admin,dc=example,dc=com" -w AdminPass123 -b "dc=example,dc=com"
```

---

## 📋 기본 명령어 Cheat Sheet

### 1. LDAP 사용자 검색

```bash
# ✅ 모든 사용자 조회
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "ou=users,dc=example,dc=com" \
  "uid=*"

# ✅ 특정 사용자 검색
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "dc=example,dc=com" \
  "uid=jenkins-admin"

# ✅ 모든 그룹 조회
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "ou=groups,dc=example,dc=com" \
  "objectClass=groupOfNames"

# ✅ 그룹의 멤버 확인
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "cn=jenkins-admins,ou=groups,dc=example,dc=com"

# ✅ TLS 연결 테스트 (636 포트)
ldapsearch -H ldaps://localhost:636 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "dc=example,dc=com" \
  "uid=*"
```

### 2. 사용자 추가

```bash
# ✅ 새 사용자 추가 (LDIF 파일)
cat > new-user.ldif << EOF
dn: cn=john-doe,ou=users,dc=example,dc=com
uid: john-doe
userPassword: JohnDoePass123
objectClass: person
objectClass: top
objectClass: inetOrgPerson
sn: John Doe
cn: john-doe
mail: john.doe@example.com
displayName: John Doe
EOF

ldapadd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -f new-user.ldif

# ✅ 또는 명령줄로 직접
ldapmodify -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" << EOF
dn: cn=jane-doe,ou=users,dc=example,dc=com
changetype: add
objectClass: person
objectClass: inetOrgPerson
cn: jane-doe
sn: Jane Doe
mail: jane.doe@example.com
userPassword: JanePassword123
EOF
```

### 3. 사용자 수정

```bash
# ✅ 비밀번호 변경
ldappasswd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -S "cn=jenkins-admin,ou=users,dc=example,dc=com"
# 새 비밀번호 입력

# ✅ 속성 수정 (LDIF)
cat > modify-user.ldif << EOF
dn: cn=john-doe,ou=users,dc=example,dc=com
changetype: modify
replace: mail
mail: newemail@example.com
-
add: telephoneNumber
telephoneNumber: +82-10-1234-5678
EOF

ldapmodify -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -f modify-user.ldif

# ✅ 사용자 삭제
ldapdelete -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  "cn=john-doe,ou=users,dc=example,dc=com"
```

### 4. 그룹 관리

```bash
# ✅ 새 그룹 생성
cat > new-group.ldif << EOF
dn: cn=developers,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: developers
description: Development team
member: cn=john-doe,ou=users,dc=example,dc=com
member: cn=jane-doe,ou=users,dc=example,dc=com
EOF

ldapadd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -f new-group.ldif

# ✅ 그룹에 멤버 추가
ldapmodify -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" << EOF
dn: cn=developers,ou=groups,dc=example,dc=com
changetype: modify
add: member
member: cn=new-developer,ou=users,dc=example,dc=com
EOF

# ✅ 그룹에서 멤버 제거
ldapmodify -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" << EOF
dn: cn=developers,ou=groups,dc=example,dc=com
changetype: modify
delete: member
member: cn=old-developer,ou=users,dc=example,dc=com
EOF
```

---

## 🔍 디버깅 명령어

```bash
# ✅ LDAP 서버 상태 확인
docker logs -f cicd-ldap

# ✅ LDAP 포트 확인
netstat -tlnp | grep ldap
# 또는
ss -tlnp | grep ldap

# ✅ LDAP 연결 테스트
telnet localhost 389      # PLAIN TEXT
openssl s_client -connect localhost:636  # TLS

# ✅ DNS 반환값 확인
getent hosts ldap.example.com

# ✅ 전체 DIT (Directory Information Tree) 덤프
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "dc=example,dc=com" \
  -L > ldap-backup.ldif

# ✅ LDIF 파일에서 복구
ldapadd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -f ldap-backup.ldif
```

---

## 🔑 테스트 계정 (미리 생성됨)

### 관리자
| 계정 | 비밀번호 | 그룹 |
|------|---------|------|
| admin | admin | role-admin |

### Jenkins
| 계정 | 비밀번호 | 그룹 |
|------|---------|------|
| jenkins-admin | JenkinsAdminPass123 | jenkins-admins |
| jenkins-user | JenkinsUserPass123 | jenkins-users |

### Rundeck
| 계정 | 비밀번호 | 그룹 |
|------|---------|------|
| rundeck-admin | RundeckAdminPass123 | rundeck-admins |
| rundeck-operator | RundeckOpPass123 | rundeck-operators |

### Nexus
| 계정 | 비밀번호 | 그룹 |
|------|---------|------|
| nexus-admin | NexusAdminPass123 | nexus-admins |
| nexus-builder | NexusBuilderPass123 | nexus-builders |

### SVN
| 계정 | 비밀번호 | 그룹 |
|------|---------|------|
| svn-admin | SvnAdminPass123 | svn-admins |
| svn-developer | SvnDevPass123 | svn-developers |

### 자동화 계정
| 계정 | 비밀번호 | 용도 |
|------|---------|------|
| build | BuildServicePass123 | CI 빌드 |
| deploy | DeployServicePass123 | 배포 자동화 |

---

## 🔗 Jenkins에서 LDAP 연동

### 1. Jenkins 관리 → 시스템 설정

```
LDAP 설정:
├─ Server: ldap://ldap:389
├─ LDAP Base DN: dc=example,dc=com
├─ User Search Base: ou=users
├─ User Search Filter: uid={0}
├─ Manager DN: cn=admin,dc=example,dc=com
├─ Manager Password: AdminPass123
├─ Group Search Base: ou=groups
├─ Group Search Filter: (objectClass=groupOfNames)
├─ Group Member Filter: memberUid={0}
├─ Group Naming: cn={0},ou=groups,dc=example,dc=com
└─ Display Name LDAP attribute: displayName
```

### 2. 권한 설정 (Role Strategy Plugin)

```
Jenkins 관리 → Manage and Assign Roles → Manage Roles

전역 역할:
├─ admin: 모든 권한
├─ developer: Job 생성/수정, 빌드 권한
└─ viewer: 읽기 전용

프로젝트 역할:
├─ project-admin: 프로젝트 완전 제어
├─ project-developer: Job 실행, 설정 수정
└─ project-viewer: 읽기 전용
```

### 3. 역할 할당

```
Jenkins 관리 → Manage and Assign Roles → Assign Roles

Global Roles:
├─ admin: jenkins-admins 그룹
├─ developer: jenkins-users 그룹
└─ viewer: ci-cd-team 그룹

Project Roles:
└─ my-project:
   ├─ project-admin: jenkins-admins
   ├─ project-developer: jenkins-users
   └─ project-viewer: ci-cd-team
```

---

## 🔐 Rundeck에서 LDAP 연동

### 1. rundeck-config.properties 수정

```properties
# LDAP 설정
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

### 2. 역할 매핑 (realm.properties)

```properties
# Rundeck 역할
admin=rundeck-admins
operator=rundeck-operators
user=ci-cd-team
```

---

## 🔒 Nexus에서 LDAP 연동

### 1. Nexus UI에서 설정

```
Administration → Security → Realms

LDAP 설정:
├─ Name: LDAP
├─ Protocol: ldap
├─ Hostname: ldap
├─ Port: 389
├─ Search Base: dc=example,dc=com
├─ Authentication Method: Simple Authentication
├─ Username or DN: cn=admin,dc=example,dc=com
├─ Password: AdminPass123
├─ User Member Of Attribute: memberOf
└─ User Object Class: inetOrgPerson
```

### 2. 저장소별 권한

```
Repositories → maven-releases
├─ Manage: nexus-admins
├─ Deploy: nexus-builders
└─ Read: ci-cd-team

Repositories → maven-snapshots
├─ Manage: nexus-admins
├─ Deploy: nexus-builders
└─ Read: ci-cd-team
```

---

## 📝 자주 사용하는 스크립트

### 모든 사용자 목록 출력

```bash
#!/bin/bash

ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "ou=users,dc=example,dc=com" \
  "uid=*" \
  uid displayName mail | grep -E "^uid:|^displayName:|^mail:"
```

### 사용자 비밀번호 초기화

```bash
#!/bin/bash

USER=$1
NEW_PASSWORD=$2

if [ -z "$USER" ] || [ -z "$NEW_PASSWORD" ]; then
  echo "Usage: $0 <username> <new_password>"
  exit 1
fi

ldappasswd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -A -P 0 \
  -s "$NEW_PASSWORD" \
  "cn=$USER,ou=users,dc=example,dc=com"

echo "✓ Password reset for $USER"
```

### 대량 사용자 추가

```bash
#!/bin/bash

# users.csv 형식:
# username,full_name,email,group
# john-doe,John Doe,john@example.com,developers

while IFS=',' read -r username fullname email group; do
  [ "$username" = "username" ] && continue  # Skip header
  
  ldapadd -H ldap://localhost:389 \
    -x \
    -D "cn=admin,dc=example,dc=com" \
    -w "AdminPass123" << EOF
dn: cn=$username,ou=users,dc=example,dc=com
uid: $username
userPassword: TempPassword123!
objectClass: person
objectClass: inetOrgPerson
sn: $fullname
cn: $username
mail: $email
displayName: $fullname
EOF
  
  echo "✓ Added $username"
done < users.csv
```

### LDAP 백업 및 복구

```bash
#!/bin/bash

# 백업
ldapsearch -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -b "dc=example,dc=com" \
  > ldap-backup-$(date +%Y%m%d-%H%M%S).ldif

echo "✓ LDAP backed up"

# 복구
ldapadd -H ldap://localhost:389 \
  -x \
  -D "cn=admin,dc=example,dc=com" \
  -w "AdminPass123" \
  -f ldap-backup-20240515-120000.ldif

echo "✓ LDAP restored"
```

---

## ⚠️ 트러블슈팅

### 문제 1: LDAP 연결 실패

```bash
# 확인 사항
1. LDAP 서버 상태
   docker ps | grep ldap

2. 포트 열려있는지 확인
   netstat -tlnp | grep 389

3. 방화벽 확인
   sudo ufw status
   sudo ufw allow 389/tcp

4. 연결 테스트
   telnet localhost 389
```

### 문제 2: 인증 실패

```bash
# 확인 사항
1. 비밀번호 정확한지 확인
2. DN 형식이 올바른지 확인
   - cn=admin,dc=example,dc=com (O)
   - cn=admin,dc=example.com (X)

3. 사용자가 존재하는지 확인
   ldapsearch -H ldap://localhost:389 \
     -x \
     -D "cn=admin,dc=example,dc=com" \
     -w "AdminPass123" \
     -b "dc=example,dc=com" \
     "uid=jenkins-admin"
```

### 문제 3: 그룹이 보이지 않음

```bash
# 확인 사항
1. 그룹 검색
   ldapsearch -H ldap://localhost:389 \
     -x \
     -D "cn=admin,dc=example,dc=com" \
     -w "AdminPass123" \
     -b "ou=groups,dc=example,dc=com" \
     "cn=*"

2. 그룹 멤버 확인
   ldapsearch -H ldap://localhost:389 \
     -x \
     -D "cn=admin,dc=example,dc=com" \
     -w "AdminPass123" \
     -b "cn=jenkins-admins,ou=groups,dc=example,dc=com"
```

### 문제 4: TLS 연결 실패

```bash
# 확인 사항
1. TLS 인증서 확인
   openssl s_client -connect localhost:636

2. 인증서 경로 확인
   ls -la ldap/certs/

3. 자체 서명 인증서 허용
   LDAPTLS_REQCERT=never ldapsearch -H ldaps://localhost:636 ...
```

---

## 📊 LDAP 구조 (DIT - Directory Information Tree)

```
dc=example,dc=com (root)
├── ou=users
│   ├── cn=admin
│   ├── cn=jenkins-admin
│   ├── cn=jenkins-user
│   ├── cn=rundeck-admin
│   ├── cn=rundeck-operator
│   ├── cn=nexus-admin
│   ├── cn=nexus-builder
│   ├── cn=svn-admin
│   ├── cn=svn-developer
│   ├── cn=build
│   └── cn=deploy
├── ou=groups
│   ├── cn=jenkins-admins
│   ├── cn=jenkins-users
│   ├── cn=rundeck-admins
│   ├── cn=rundeck-operators
│   ├── cn=nexus-admins
│   ├── cn=nexus-builders
│   ├── cn=svn-admins
│   ├── cn=svn-developers
│   └── cn=ci-cd-team
└── ou=roles
    ├── cn=role-admin
    ├── cn=role-developer
    └── cn=role-operator
```

---

## 🎯 빠른 참조 (Most Used Commands)

```bash
# 사용자 검색
ldapsearch -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" \
  -b "ou=users,dc=example,dc=com" "uid=*"

# 비밀번호 변경
ldappasswd -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" \
  -S "cn=username,ou=users,dc=example,dc=com"

# 사용자 추가
ldapadd -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" -f user.ldif

# 사용자 삭제
ldapdelete -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" \
  "cn=username,ou=users,dc=example,dc=com"

# 속성 수정
ldapmodify -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" -f modify.ldif

# 그룹에 멤버 추가
ldapmodify -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" << EOF
dn: cn=groupname,ou=groups,dc=example,dc=com
changetype: modify
add: member
member: cn=username,ou=users,dc=example,dc=com
EOF

# LDAP 백업
ldapsearch -x -D "cn=admin,dc=example,dc=com" -w "AdminPass123" \
  -b "dc=example,dc=com" > ldap-backup.ldif
```

**이제 LDAP를 5분 안에 구축하고 관리할 수 있습니다!** 🚀
