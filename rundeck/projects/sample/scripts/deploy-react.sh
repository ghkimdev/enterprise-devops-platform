#!/bin/bash
# deploy-react.sh — React (raw tar.gz) VM 배포 스크립트
#
# 환경변수:
#   APP=sample-react
#   RELEASE_NAME=r-sample-react-20260525_143012
#   APP_VERSION=r-sample-react-20260525_143012.tar.gz   (= raw repo의 filename)
#   ENV_NAME=dev|stg|prod
#   TEAM=web-team
#   NEXUS_BASE, NEXUS_USER, NEXUS_PASS

set -euo pipefail

: "${APP:?APP required}"
: "${RELEASE_NAME:?RELEASE_NAME required}"
: "${APP_VERSION:?APP_VERSION required}"
: "${ENV_NAME:?ENV_NAME required}"
: "${TEAM:=unknown}"
: "${NEXUS_BASE:?NEXUS_BASE required}"
: "${NEXUS_USER:?NEXUS_USER required}"
: "${NEXUS_PASS:?NEXUS_PASS required}"

TAR_NAME="${RELEASE_NAME}.tar.gz"
ARTIFACT_URL="${NEXUS_BASE}/repository/releases/${APP}/${TAR_NAME}"

APP_DIR="/var/www/${APP}"
RELEASES_DIR="${APP_DIR}/releases"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_NAME}"
CURRENT_LINK="${APP_DIR}/current"
DOCROOT="/var/www/html/${APP}"   # nginx가 서빙하는 경로

echo "=================================================="
echo "DEPLOY ${APP} → ${ENV_NAME}"
echo "=================================================="
echo "RELEASE_NAME : ${RELEASE_NAME}"
echo "TEAM         : ${TEAM}"
echo "ARTIFACT     : ${ARTIFACT_URL}"
echo "=================================================="

sudo mkdir -p "${RELEASES_DIR}"
sudo chown -R deploy:deploy "${APP_DIR}"

if [ -d "${RELEASE_DIR}" ]; then
    echo "Release ${RELEASE_NAME} 이미 존재. 다운로드 스킵."
else
    mkdir -p "${RELEASE_DIR}"

    echo "Downloading tar.gz..."
    curl -fsS -u "${NEXUS_USER}:${NEXUS_PASS}" -o "/tmp/${TAR_NAME}" "${ARTIFACT_URL}"
    tar xzf "/tmp/${TAR_NAME}" -C "${RELEASE_DIR}"
    rm -f "/tmp/${TAR_NAME}"
fi

# runtime-config.js 환경별 주입 (있는 경우)
ENV_CONFIG="/etc/${APP}/runtime-config-${ENV_NAME}.js"
if [ -f "${ENV_CONFIG}" ]; then
    sudo cp "${ENV_CONFIG}" "${RELEASE_DIR}/runtime-config.js"
    echo "Injected runtime-config from ${ENV_CONFIG}"
fi

# symlink 교체
sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}.new"
sudo mv -Tf "${CURRENT_LINK}.new" "${CURRENT_LINK}"

# 오래된 release 정리
KEEP=3
cd "${RELEASES_DIR}"
ls -1t | tail -n +$((KEEP + 1)) | xargs -r rm -rf

# Health check
HEALTH_URL="http://localhost/healthz"
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
