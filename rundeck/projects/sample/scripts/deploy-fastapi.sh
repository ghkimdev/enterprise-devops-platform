#!/bin/bash
# deploy-fastapi.sh — FastAPI (raw tar.gz + venv) VM 배포 스크립트
#
# 환경변수:
#   APP=sample-fastapi
#   RELEASE_NAME=r-sample-fastapi-20260525_143012
#   APP_VERSION=...                                     (= raw filename)
#   ENV_NAME=dev|stg|prod
#   TEAM=ml-team
#   NEXUS_BASE, NEXUS_USER, NEXUS_PASS
#   PIP_INDEX_URL                                       (Nexus PyPI proxy)
#   PIP_TRUSTED_HOST

set -euo pipefail

: "${APP:?APP required}"
: "${RELEASE_NAME:?RELEASE_NAME required}"
: "${APP_VERSION:?APP_VERSION required}"
: "${ENV_NAME:?ENV_NAME required}"
: "${TEAM:=unknown}"
: "${NEXUS_BASE:?NEXUS_BASE required}"
: "${NEXUS_USER:?NEXUS_USER required}"
: "${NEXUS_PASS:?NEXUS_PASS required}"
: "${PIP_INDEX_URL:?PIP_INDEX_URL required}"
: "${PIP_TRUSTED_HOST:=}"

TAR_NAME="${RELEASE_NAME}.tar.gz"
SHA_NAME="${RELEASE_NAME}.sha256"
ARTIFACT_URL="${NEXUS_BASE}/repository/releases/${APP}/${TAR_NAME}"
SHA_URL="${NEXUS_BASE}/repository/releases/${APP}/${SHA_NAME}"

APP_DIR="/opt/${APP}"
RELEASES_DIR="${APP_DIR}/releases"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_NAME}"
CURRENT_LINK="${APP_DIR}/current"
LOGS_DIR="${APP_DIR}/logs"
SYSTEMD_UNIT="/etc/systemd/system/${APP}.service"

echo "=================================================="
echo "DEPLOY ${APP} → ${ENV_NAME}"
echo "=================================================="
echo "RELEASE_NAME : ${RELEASE_NAME}"
echo "TEAM         : ${TEAM}"
echo "ARTIFACT     : ${ARTIFACT_URL}"
echo "=================================================="

sudo mkdir -p "${RELEASES_DIR}" "${LOGS_DIR}"
sudo chown -R deploy:deploy "${APP_DIR}"

if [ -d "${RELEASE_DIR}" ]; then
    echo "Release ${RELEASE_NAME} 이미 존재. 다운로드 스킵."
else
    mkdir -p "${RELEASE_DIR}"

    echo "Downloading tar.gz..."
    curl -fsS -u "${NEXUS_USER}:${NEXUS_PASS}" -o "/tmp/${TAR_NAME}" "${ARTIFACT_URL}"

    echo "Verifying SHA256..."
    EXPECTED_SHA=$(curl -fsS -u "${NEXUS_USER}:${NEXUS_PASS}" "${SHA_URL}" | awk '{print $1}')
    ACTUAL_SHA=$(sha256sum "/tmp/${TAR_NAME}" | awk '{print $1}')
    if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
        echo "SHA256 mismatch!"
        rm -f "/tmp/${TAR_NAME}"
        rm -rf "${RELEASE_DIR}"
        exit 1
    fi
    echo "SHA256 OK"

    tar xzf "/tmp/${TAR_NAME}" -C "${RELEASE_DIR}"
    rm -f "/tmp/${TAR_NAME}"

    # venv 생성 (release별로 격리)
    echo "Creating venv..."
    python3 -m venv "${RELEASE_DIR}/.venv"
    "${RELEASE_DIR}/.venv/bin/pip" install --upgrade pip

    PIP_OPTS=( --index-url "${PIP_INDEX_URL}" )
    [ -n "${PIP_TRUSTED_HOST}" ] && PIP_OPTS+=( --trusted-host "${PIP_TRUSTED_HOST}" )
    "${RELEASE_DIR}/.venv/bin/pip" install "${PIP_OPTS[@]}" -r "${RELEASE_DIR}/requirements.txt"

    # uvicorn 자체도 venv에 설치 (런타임 의존성)
    "${RELEASE_DIR}/.venv/bin/pip" install "${PIP_OPTS[@]}" 'uvicorn[standard]'

    echo "Venv ready: ${RELEASE_DIR}/.venv"
fi

# systemd unit 갱신
TEMPLATE="/etc/${APP}/systemd.template"
if [ -f "${TEMPLATE}" ]; then
    sudo sed \
        -e "s|__RELEASE_NAME__|${RELEASE_NAME}|g" \
        -e "s|__ENV_NAME__|${ENV_NAME}|g" \
        -e "s|__TEAM__|${TEAM}|g" \
        "${TEMPLATE}" > /tmp/${APP}.service.tmp
    sudo mv /tmp/${APP}.service.tmp "${SYSTEMD_UNIT}"
    sudo systemctl daemon-reload
fi

# symlink 교체
sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}.new"
sudo mv -Tf "${CURRENT_LINK}.new" "${CURRENT_LINK}"

# 서비스 재시작
sudo systemctl enable "${APP}.service" 2>/dev/null || true
sudo systemctl restart "${APP}.service"

# 오래된 release 정리
KEEP=3
cd "${RELEASES_DIR}"
ls -1t | tail -n +$((KEEP + 1)) | xargs -r rm -rf

# Health check
HEALTH_URL="http://localhost:8000/healthz"
echo "Health check: ${HEALTH_URL}"
for i in $(seq 1 12); do
    if curl -fsS --max-time 3 "${HEALTH_URL}" > /dev/null; then
        echo "Health OK (attempt ${i})"
        echo "DEPLOY SUCCESS: ${APP} ${RELEASE_NAME} → ${ENV_NAME}"
        exit 0
    fi
    echo "Waiting for health... (${i}/12)"
    sleep 5
done

echo "Health check 실패"
exit 1
