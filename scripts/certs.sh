#!/bin/bash
# LDAPS + 모든 애플리케이션에 SSL/TLS 인증서 빠르게 적용하기

set -euo pipefail 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CERT_ROOT="${PROJECT_ROOT}/certs"

IDENTITY_DIR="${PROJECT_ROOT}/identity"
CICD_DIR="${PROJECT_ROOT}/cicd"

# ============================================
# 설정
# ============================================
DAYS=365
KEY_SIZE=4096
CA_PASS="${CA_PASS:-$(openssl rand -base64 24)}"

COUNTRY="KR"
STATE="Seoul"
CITY="Seoul"
ORG="MyCompany"
OU="IT"
DOMAIN="example.com"

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SSL/TLS 인증서 자동 생성 및 적용${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# 1. 디렉토리 구조 생성
# ============================================
echo -e "${YELLOW}[1/11] 디렉토리 구조 생성...${NC}"
rm -rf "${CERT_ROOT:?}"/*
mkdir -p \
  "${CERT_ROOT}/ca" \
  "${CERT_ROOT}/ldap" \
  "${CERT_ROOT}/jenkins" \
  "${CERT_ROOT}/rundeck" \
  "${CERT_ROOT}/nexus" \
  "${CERT_ROOT}/svn" \
  "${CERT_ROOT}/grafana"
mkdir -p ${IDENTITY_DIR}/ldap/certs
mkdir -p ${CICD_DIR}/jenkins/certs
mkdir -p ${CICD_DIR}/rundeck/certs
mkdir -p ${CICD_DIR}/nexus/certs
mkdir -p ${CICD_DIR}/svn/certs
echo -e "${GREEN}✓ 디렉토리 생성 완료${NC}"
echo ""

printf '%s' "$CA_PASS" > ${CERT_ROOT}/ca/ca.pass

# ============================================
# 2. CA (인증 기관) 생성
# ============================================
echo -e "${YELLOW}[2/11] CA 개인키 생성...${NC}"
openssl genrsa -aes256 \
  -out "${CERT_ROOT}/ca/ca.key" \
  -passout pass:${CA_PASS} \
  ${KEY_SIZE}
echo -e "${GREEN}✓ CA 개인키 생성 완료${NC}"
echo ""

echo -e "${YELLOW}[3/11] CA 자체 서명 인증서 생성...${NC}"
openssl req \
  -new \
  -x509 \
  -days "${DAYS}" \
  -key "${CERT_ROOT}/ca/ca.key" \
  -passin "pass:${CA_PASS}" \
  -out "${CERT_ROOT}/ca/ca.crt" \
  -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${ORG}-CA"
echo -e "${GREEN}✓ CA 인증서 생성 완료${NC}"
echo ""

# ============================================
# 공통 SAN 인증서 생성 함수
# ============================================
create_cert_with_san() {
  NAME=$1
  DIR=$2

  mkdir -p ${DIR}

  # SAN config 생성
  cat > ${DIR}/san.conf << EOF
[req]
default_bits = ${KEY_SIZE}
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C=${COUNTRY}
ST=${STATE}
L=${CITY}
O=${ORG}
OU=${OU}
CN=${NAME}.${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${NAME}
DNS.2 = ${NAME}.${DOMAIN}
DNS.3 = *.${NAME}.${DOMAIN}
DNS.4 = localhost
IP.1 = 127.0.0.1
EOF

  # key 생성
  openssl genrsa -out ${DIR}/${NAME}.key ${KEY_SIZE}

  # CSR 생성
  openssl req -new \
    -key ${DIR}/${NAME}.key \
    -out ${DIR}/${NAME}.csr \
    -config ${DIR}/san.conf

  # 인증서 발급 (SAN 포함)
  openssl x509 -req -days ${DAYS} \
    -in ${DIR}/${NAME}.csr \
    -CA "${CERT_ROOT}/ca/ca.crt" \
    -CAkey "${CERT_ROOT}/ca/ca.key" \
    -passin pass:${CA_PASS} \
    -CAcreateserial \
    -out ${DIR}/${NAME}.crt \
    -extensions req_ext \
    -extfile ${DIR}/san.conf

  cat \
    "${DIR}/${NAME}.crt" \
    "${CERT_ROOT}/ca/ca.crt" \
    > "${DIR}/fullchain.pem"
  cp "${DIR}/${NAME}.key" \
     "${DIR}/privkey.pem"
}

# ============================================
# 3. LDAP 인증서 생성
# ============================================
echo -e "${YELLOW}[4/11] LDAP 인증서 생성...${NC}"
create_cert_with_san \
  "ldap" \
  "${CERT_ROOT}/ldap"
echo -e "${GREEN}✓ LDAP 인증서 생성 완료${NC}"
echo ""

# ============================================
# 4. Jenkins 인증서 생성
# ============================================
echo -e "${YELLOW}[5/11] Jenkins 인증서 생성...${NC}"
create_cert_with_san \
  "jenkins" \
  "${CERT_ROOT}/jenkins"
echo -e "${GREEN}✓ Jenkins 인증서 생성 완료${NC}"
echo ""

# ============================================
# 5. Rundeck 인증서 생성
# ============================================
echo -e "${YELLOW}[6/11] Rundeck 인증서 생성...${NC}"
create_cert_with_san \
  "rundeck" \
  "${CERT_ROOT}/rundeck"
echo -e "${GREEN}✓ Rundeck 인증서 생성 완료${NC}"
echo ""

# ============================================
# 6. Nexus 인증서 생성
# ============================================
echo -e "${YELLOW}[7/10] Nexus 인증서 생성...${NC}"
create_cert_with_san \
  "nexus" \
  "${CERT_ROOT}/nexus"
echo -e "${GREEN}✓ Nexus 인증서 생성 완료${NC}"
echo ""

# ============================================
# 7. SVN 인증서 생성
# ============================================
echo -e "${YELLOW}[8/10] SVN 인증서 생성...${NC}"
create_cert_with_san \
  "svn" \
  "${CERT_ROOT}/svn"
echo -e "${GREEN}✓ SVN 인증서 생성 완료${NC}"
echo ""

# ============================================
# 8. Grafana 인증서 생성
# ============================================
echo -e "${YELLOW}[9/11] Grafana 인증서 생성...${NC}"
create_cert_with_san \
  "grafana" \
  "${CERT_ROOT}/grafana"
echo -e "${GREEN}✓ Grafana 인증서 생성 완료${NC}"
echo ""

# ============================================
# 9. CA 인증서 배치
# ============================================
echo -e "${YELLOW}[10/11] CA 인증서 배치...${NC}"
cp "${CERT_ROOT}/ca/ca.crt" \
   "${IDENTITY_DIR}/ldap/certs"
cp "${CERT_ROOT}/ldap/ldap.crt" \
   "${IDENTITY_DIR}/ldap/certs"
cp "${CERT_ROOT}/ldap/ldap.key" \
   "${IDENTITY_DIR}/ldap/certs"
cp "${CERT_ROOT}/ca/ca.crt" \
   "${CICD_DIR}/jenkins/certs"
cp "${CERT_ROOT}/ca/ca.crt" \
   "${CICD_DIR}/rundeck/certs"
cp "${CERT_ROOT}/ca/ca.crt" \
   "${CICD_DIR}/nexus/certs"
cp "${CERT_ROOT}/ca/ca.crt" \
   "${CICD_DIR}/svn/certs"
echo -e "${GREEN}✓ CA 인증서 배치 완료${NC}"
echo ""

# ============================================
# 9. 파일 권한 설정
# ============================================
echo -e "${YELLOW}[11/11] 파일 권한 설정...${NC}"
find "${CERT_ROOT}" -name "*.key" -exec chmod 600 {} \;
find "${CERT_ROOT}" -name "*.crt" -exec chmod 644 {} \;
find "${CERT_ROOT}" -name "*.pem" -exec chmod 644 {} \;
echo -e "${GREEN}✓ 파일 권한 설정 완료${NC}"
echo ""

# ============================================
# 요약
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ SSL/TLS 인증서 생성 및 설정 완료!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}생성된 인증서 및 파일:${NC}"
echo ""
echo "CA:"
echo "  • certs/ca/ca.crt (CA 공개 인증서)"
echo "  • certs/ca/ca.key (CA 개인키)"
echo ""
echo "LDAP (LDAPS):"
echo "  • certs/ldap/ldap.crt"
echo "  • certs/ldap/ldap.key"
echo ""
echo "Jenkins:"
echo "  • certs/jenkins/jenkins.crt"
echo "  • certs/jenkins/jenkins.key"
echo ""
echo "Rundeck:"
echo "  • certs/rundeck/rundeck.crt"
echo "  • certs/rundeck/rundeck.key"
echo ""
echo "Nexus:"
echo "  • certs/nexus/nexus.crt"
echo "  • certs/nexus/nexus.key"
echo ""
echo "SVN:"
echo "  • certs/svn/svn.crt"
echo "  • certs/svn/svn.key"
echo ""
echo "Grafana:"
echo "  • certs/grafana/grafana.crt"
echo "  • certs/grafana/grafana.key"
echo ""
echo -e "${BLUE}========================================${NC}"
