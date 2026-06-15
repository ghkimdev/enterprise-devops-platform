#!/bin/bash
# init.sh — 공개 배포용 1회 환경 초기화 (전부 멱등: 재실행해도 안전)
#
# 인증서 전략: 전부 Let's Encrypt 공개 인증서로 통일
#   웹(nginx: grafana/jenkins/nexus/rundeck/svn) 및 LDAP(ldaps://ldap.ghlab.dev:636)
#   → *.ghlab.dev 와일드카드 하나로 커버 (LDAP 은 ldap.ghlab.dev 별칭으로 접속)
#   → 내부 사설 CA 불필요. 공개 CA(ISRG/LE)는 모든 베이스 이미지가 이미 신뢰.
#
# 전제: 먼저 Let's Encrypt 와일드카드 + 레지스트리 호스트를 발급해 둘 것
#   (docker.nexus.ghlab.dev 는 2단계라 *.ghlab.dev 로 안 덮이므로 명시 필요)
#   sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/cf.ini \
#     -d ghlab.dev -d '*.ghlab.dev' -d docker.nexus.ghlab.dev
#
# 실행: ./init.sh   (sudo 없이 — 권한 필요한 단계만 내부에서 sudo)
# 이후: ./up.sh
#
# 단계:
#   1) .env 생성              4) Rundeck 배포 SSH 키
#   2) Nexus metrics 패스워드  5) docker 그룹 권한
#   3) Let's Encrypt 인증서 배치 (웹 + LDAP + CA)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${YELLOW}[$1] $2${NC}"; }
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
skip() { echo -e "  - $1 (이미 있음 — 스킵)"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CERT_ROOT="${PROJECT_ROOT}/ingress/nginx/certs"
IDENTITY_DIR="${PROJECT_ROOT}/identity"

# Let's Encrypt 발급 위치 (필요 시 LE_LIVE 환경변수로 덮어쓰기 가능)
LE_LIVE="${LE_LIVE:-/etc/letsencrypt/live/ghlab.dev}"
# nginx 가 TLS 종단하는 웹 서비스
WEB_SERVICES=(grafana jenkins nexus rundeck svn)

SECRET_DIR="${PROJECT_ROOT}/observability/prometheus/secrets"
KEY_DIR="${PROJECT_ROOT}/cicd/rundeck/keys/project/sample"

# ── 1) .env 생성 ────────────────────────────────────────────────────
step 1 ".env 생성"
if [ -f "${PROJECT_ROOT}/.env" ]; then
    skip ".env"
else
    cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
    ok ".env 생성 — ${RED}비밀번호 값(<change-me>)을 반드시 수정하세요${NC}"
fi

# ── 2) Nexus metrics 패스워드 ───────────────────────────────────────
step 2 "Nexus metrics 패스워드"
if [ -f "${SECRET_DIR}/nexus_metrics" ]; then
    skip "Nexus metrics"
else
    mkdir -p "${SECRET_DIR}"
    grep '^NEXUS_METRICS_PASSWORD=' "${PROJECT_ROOT}/.env" | cut -d= -f2- | tr -d '\n' \
      > "${SECRET_DIR}/nexus_metrics"
    ok "nexus_metrics 생성 — ${RED}.env 의 비밀번호를 먼저 수정했는지 확인${NC}"
fi

# ── 3) Let's Encrypt 인증서 배치 (웹 + LDAP + CA) ───────────────────
step 3 "Let's Encrypt 인증서 배치"
if [ ! -f "${LE_LIVE}/fullchain.pem" ]; then
    echo -e "  ${RED}Let's Encrypt 인증서를 찾을 수 없습니다: ${LE_LIVE}/fullchain.pem${NC}"
    echo -e "  ${YELLOW}먼저 발급하세요 (docker.nexus 는 2단계라 와일드카드로 안 덮이므로 명시):${NC}"
    echo -e "    sudo certbot certonly --dns-cloudflare \\"
    echo -e "      --dns-cloudflare-credentials /root/cf.ini \\"
    echo -e "      -d ghlab.dev -d '*.ghlab.dev' -d docker.nexus.ghlab.dev"
    echo -e "  ${YELLOW}발급 후 ./init.sh 를 다시 실행하세요.${NC}"
    exit 1
fi

# (3-1) 웹: nginx 가 읽는 certs/<svc>/{fullchain,privkey}.pem
for s in "${WEB_SERVICES[@]}"; do
    sudo install -D -m644 "${LE_LIVE}/fullchain.pem" "${CERT_ROOT}/${s}/fullchain.pem"
    sudo install -D -m600 "${LE_LIVE}/privkey.pem"   "${CERT_ROOT}/${s}/privkey.pem"
done
ok "웹 ${#WEB_SERVICES[@]}종(${WEB_SERVICES[*]}) → Let's Encrypt"

# (3-2) LDAP: osixia 파일명(fullchain.pem/privkey.pem/chain.pem)으로 배치
#       ldap.ghlab.dev 는 *.ghlab.dev SAN 에 매칭되어 검증 통과
sudo install -D -m644 "${LE_LIVE}/fullchain.pem" "${IDENTITY_DIR}/ldap/certs/fullchain.pem"
sudo install -D -m600 "${LE_LIVE}/privkey.pem"   "${IDENTITY_DIR}/ldap/certs/privkey.pem"
sudo install -D -m644 "${LE_LIVE}/chain.pem"     "${IDENTITY_DIR}/ldap/certs/chain.pem"
ok "LDAP → Let's Encrypt (ldaps://ldap.ghlab.dev:636)"

# ── 4) Rundeck 배포 SSH 키 ──────────────────────────────────────────
step 4 "Rundeck 배포 SSH 키"
if [ -f "${KEY_DIR}/deploy-key" ]; then
    skip "deploy-key"
else
    mkdir -p "${KEY_DIR}"
    # -N "" : 무인 접속을 위해 빈 패스프레이즈 (Rundeck 이 자동 SSH)
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/deploy-key" -C "rundeck-deploy" >/dev/null
    ok "deploy-key 생성 (공개키: ${KEY_DIR}/deploy-key.pub)"
    echo -e "    ${RED}주의: 개인키(deploy-key)는 .gitignore의 rundeck/keys/ 포함 확인${NC}"
fi

# ── 5) docker 그룹 권한 ─────────────────────────────────────────────
step 5 "docker 그룹 권한"
ME="$(id -un)"
if id -nG "${ME}" | grep -qw docker; then
    skip "${ME} 이미 docker 그룹 소속"
else
    sudo usermod -aG docker "${ME}"
    ok "${ME} 를 docker 그룹에 추가"
    echo -e "    ${RED}로그아웃 후 재로그인(또는 'newgrp docker')해야 적용됩니다.${NC}"
fi

echo -e "\n${GREEN}=================================================="
echo -e " init 완료 — 다음: ./up.sh 로 기동"
echo -e "==================================================${NC}"
echo -e "${YELLOW}인증서: 웹 + LDAP 모두 Let's Encrypt 공개 인증서로 통일${NC}"
echo -e "${RED}리마인더: .env 의 비밀번호 값을 수정했는지 확인하세요.${NC}"
