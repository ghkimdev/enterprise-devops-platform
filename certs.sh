#!/bin/bash
# LDAPS + 모든 애플리케이션에 SSL/TLS 인증서 빠르게 적용하기

set -euo pipefail 

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
rm -rf nginx/certs
rm -rf ldap/certs
rm -rf jenkins/certs
rm -rf rundeck/certs
rm -rf nexus/certs
rm -rf svn/certs
mkdir -p nginx/certs/{ldap,jenkins,rundeck,nexus,svn,grafana}
mkdir -p ldap/certs
mkdir -p jenkins/certs
mkdir -p rundeck/certs
mkdir -p nexus/certs
mkdir -p svn/certs
echo -e "${GREEN}✓ 디렉토리 생성 완료${NC}"
echo ""

cd nginx/certs
printf '%s' "$CA_PASS" > ca.pass

# ============================================
# 2. CA (인증 기관) 생성
# ============================================
echo -e "${YELLOW}[2/11] CA 개인키 생성...${NC}"
openssl genrsa -aes256 -out ca.key -passout pass:${CA_PASS} ${KEY_SIZE}
echo -e "${GREEN}✓ CA 개인키 생성 완료${NC}"
echo ""

echo -e "${YELLOW}[3/11] CA 자체 서명 인증서 생성...${NC}"
openssl req -new -x509 -days ${DAYS} -key ca.key -passin pass:${CA_PASS} \
  -out ca.crt \
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
    -CA ca.crt \
    -CAkey ca.key -passin pass:${CA_PASS} \
    -CAcreateserial \
    -out ${DIR}/${NAME}.crt \
    -extensions req_ext \
    -extfile ${DIR}/san.conf

  cat ${DIR}/${NAME}.crt ca.crt > ${DIR}/fullchain.pem
  cp ${DIR}/${NAME}.key ${DIR}/privkey.pem
}

# ============================================
# 3. LDAP 인증서 생성
# ============================================
echo -e "${YELLOW}[4/11] LDAP 인증서 생성...${NC}"
create_cert_with_san "ldap" "ldap"
echo -e "${GREEN}✓ LDAP 인증서 생성 완료${NC}"
echo ""

# ============================================
# 4. Jenkins 인증서 생성
# ============================================
echo -e "${YELLOW}[5/11] Jenkins 인증서 생성...${NC}"
create_cert_with_san "jenkins" "jenkins"
echo -e "${GREEN}✓ Jenkins 인증서 생성 완료${NC}"
echo ""

# ============================================
# 5. Rundeck 인증서 생성
# ============================================
echo -e "${YELLOW}[6/11] Rundeck 인증서 생성...${NC}"
create_cert_with_san "rundeck" "rundeck"
echo -e "${GREEN}✓ Rundeck 인증서 생성 완료${NC}"
echo ""

# ============================================
# 6. Nexus 인증서 생성
# ============================================
echo -e "${YELLOW}[7/10] Nexus 인증서 생성...${NC}"
create_cert_with_san "nexus" "nexus"
echo -e "${GREEN}✓ Nexus 인증서 생성 완료${NC}"
echo ""

# ============================================
# 7. SVN 인증서 생성
# ============================================
echo -e "${YELLOW}[8/10] SVN 인증서 생성...${NC}"
create_cert_with_san "svn" "svn"
echo -e "${GREEN}✓ SVN 인증서 생성 완료${NC}"
echo ""

# ============================================
# 8. Grafana 인증서 생성
# ============================================
echo -e "${YELLOW}[9/11] Grafana 인증서 생성...${NC}"
create_cert_with_san "grafana" "grafana"
echo -e "${GREEN}✓ Grafana 인증서 생성 완료${NC}"
echo ""

# ============================================
# 9. CA 인증서 배치
# ============================================
echo -e "${YELLOW}[10/11] CA 인증서 배치...${NC}"
cp ca.crt ../../ldap/certs
cp ldap/ldap.crt ../../ldap/certs
cp ldap/ldap.key ../../ldap/certs
cp ca.crt ../../jenkins/certs
cp ca.crt ../../rundeck/certs
cp ca.crt ../../nexus/certs
cp ca.crt ../../svn/certs
echo -e "${GREEN}✓ CA 인증서 배치 완료${NC}"
echo ""

# ============================================
# 9. 파일 권한 설정
# ============================================
echo -e "${YELLOW}[11/11] 파일 권한 설정...${NC}"
find . -name "*.key" -exec chmod 600 {} \;
find . -name "*.crt" -exec chmod 644 {} \;
echo -e "${GREEN}✓ 파일 권한 설정 완료${NC}"
echo ""

cd ..

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
echo "  • nginx/certs/ca.crt (CA 공개 인증서)"
echo "  • nginx/certs/ca.key (CA 개인키)"
echo ""
echo "LDAP (LDAPS):"
echo "  • nginx/certs/ldap/ldap.crt"
echo "  • nginx/certs/ldap/ldap.key"
echo ""
echo "Jenkins:"
echo "  • nginx/certs/jenkins/jenkins.crt"
echo "  • nginx/certs/jenkins/jenkins.key"
echo ""
echo "Rundeck:"
echo "  • nginx/certs/rundeck/rundeck.crt"
echo "  • nginx/certs/rundeck/rundeck.key"
echo ""
echo "Nexus:"
echo "  • nginx/certs/nexus/nexus.crt"
echo "  • nginx/certs/nexus/nexus.key"
echo ""
echo "SVN:"
echo "  • nginx/certs/svn/svn.crt"
echo "  • nginx/certs/svn/svn.key"
echo ""
echo "Grafana:"
echo "  • nginx/certs/grafana/grafana.crt"
echo "  • nginx/certs/grafana/grafana.key"
echo ""
echo -e "${BLUE}========================================${NC}"
