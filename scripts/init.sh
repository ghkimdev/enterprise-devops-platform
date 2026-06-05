#!/bin/bash
# init.sh — 최초 1회 환경 초기화 (전부 멱등: 재실행해도 안전)
#
# 실행: ./init.sh      (sudo 없이 실행 — 권한 필요한 단계만 내부에서 sudo 사용)
# 이후: ./up.sh        (서비스 기동)
#
# 단계:
#   1) .env 생성              5) 시스템 CA 신뢰
#   2) TLS 인증서(certs.sh)    6) Docker registry CA 등록
#   3) Rundeck 배포 SSH 키     7) docker.sock 권한
#   4) /etc/hosts 도메인

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${YELLOW}[$1] $2${NC}"; }
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
skip() { echo -e "  - $1 (이미 있음 — 스킵)"; }

# 프로젝트 루트(스크립트 위치) 기준으로 동작
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CA_CRT="${PROJECT_ROOT}/certs/ca/ca.crt"

REGISTRY="nexus.example.com:5000"
DOMAINS=(jenkins.example.com nexus.example.com rundeck.example.com svn.example.com grafana.example.com)
HOSTS_MARKER="# enterprise-devops-platform"
KEY_DIR="${PROJECT_ROOT}/cicd/rundeck/keys/project/sample"

# ── 1) .env 생성 ────────────────────────────────────────────────────
step 1 ".env 생성"
if [ -f .env ]; then
    skip ".env"
else
    cp ${PROJECT_ROOT}/.env.example ${PROJECT_ROOT}/.env
    ok ".env 생성 — ${RED}비밀번호 값(<change-me>)을 반드시 수정하세요${NC}"
fi

# ── 2) TLS 인증서 ───────────────────────────────────────────────────
step 2 "TLS 인증서 생성 (certs.sh)"
if [ -f "${CA_CRT}" ]; then
    skip "인증서"
else
    ${PROJECT_ROOT}/scripts/certs.sh
    ok "인증서 생성 (CA: ${CA_CRT})"
fi

# ── 3) Rundeck 배포 SSH 키 ──────────────────────────────────────────
step 3 "Rundeck 배포 SSH 키"
if [ -f "${KEY_DIR}/deploy-key" ]; then
    skip "deploy-key"
else
    mkdir -p "${KEY_DIR}"
    # -N "" : 무인 접속을 위해 빈 패스프레이즈 (Rundeck이 자동 SSH)
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/deploy-key" -C "rundeck-deploy" >/dev/null
    ok "deploy-key 생성 (공개키: ${KEY_DIR}/deploy-key.pub)"
    echo -e "    ${RED}주의: 개인키(deploy-key)는 .gitignore에 rundeck/keys/ 포함 확인${NC}"
fi

# ── 4) /etc/hosts 사설 도메인 ───────────────────────────────────────
step 4 "/etc/hosts 도메인 등록"
if grep -q "${HOSTS_MARKER}" /etc/hosts; then
    skip "도메인"
else
    {
        echo "${HOSTS_MARKER}"
        echo "127.0.0.1 ${DOMAINS[*]}"
    } | sudo tee -a /etc/hosts >/dev/null
    ok "등록: ${DOMAINS[*]} → 127.0.0.1"
fi

# ── 5) 시스템 CA 신뢰 (호스트 curl 등이 사설 CA 신뢰) ───────────────
step 5 "시스템 CA 신뢰 등록"
sudo cp "${CA_CRT}" /usr/local/share/ca-certificates/enterprise-devops-platform.crt
sudo update-ca-certificates >/dev/null
ok "update-ca-certificates 완료"

# ── 6) Docker registry CA (push/pull 인증서 검증용) ─────────────────
step 6 "Docker registry CA 등록 (${REGISTRY})"
sudo mkdir -p "/etc/docker/certs.d/${REGISTRY}"
sudo cp "${CA_CRT}" "/etc/docker/certs.d/${REGISTRY}/ca.crt"
ok "/etc/docker/certs.d/${REGISTRY}/ca.crt"

# ── 7) docker 그룹 권한 ─────────────────────────────────────────────
step 7 "docker 그룹 권한"
ME="$(id -un)"
if id -nG "${ME}" | grep -qw docker; then
    skip "${ME} 이미 docker 그룹 소속"
else
    sudo usermod -aG docker "${ME}"
    ok "${ME} 를 docker 그룹에 추가"
    echo -e "    ${RED}로그아웃 후 재로그인(또는 'newgrp docker')해야 적용됩니다.${NC}"
    echo -e "    ${YELLOW}그 전까지는 docker 명령에 sudo가 필요할 수 있습니다.${NC}"
fi

echo -e "\n${GREEN}=================================================="
echo -e " init 완료 — 다음: ./up.sh 로 기동"
echo -e "==================================================${NC}"
echo -e "${RED}리마인더: .env 의 비밀번호 값을 수정했는지 확인하세요.${NC}"
