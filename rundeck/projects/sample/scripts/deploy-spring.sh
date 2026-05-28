#!/bin/bash
# deploy-spring.sh — Spring (Maven artifact) VM 배포 스크립트
#
# Rundeck deploy-spring 잡이 각 노드에서 실행한다.
# 환경변수로 전달받는 값:
#   APP=sample-spring
#   RELEASE_NAME=r-sample-spring-20260525_143012
#   APP_VERSION=20260525_143012      (= maven version)
#   ENV_NAME=dev|stg|prod
#   TEAM=payment-team
#   NEXUS_BASE=http://nexus:8081
#   NEXUS_USER, NEXUS_PASS

set -euo pipefail

: "${APP:?APP required}"
: "${RELEASE_NAME:?RELEASE_NAME required}"
: "${APP_VERSION:?APP_VERSION required}"
: "${ENV_NAME:?ENV_NAME required}"
: "${TEAM:=unknown}"
: "${NEXUS_BASE:?NEXUS_BASE required}"
: "${NEXUS_USER:?NEXUS_USER required}"
: "${NEXUS_PASS:?NEXUS_PASS required}"

GROUP_PATH="com/example"
ARTIFACT_ID="${APP}"
ARTIFACT_URL="${NEXUS_BASE}/repository/maven-releases/${GROUP_PATH}/${ARTIFACT_ID}/${APP_VERSION}/${ARTIFACT_ID}-${APP_VERSION}.jar"
SHA_URL="${ARTIFACT_URL}.sha256"

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
echo "APP_VERSION  : ${APP_VERSION}"
echo "TEAM         : ${TEAM}"
echo "ARTIFACT     : ${ARTIFACT_URL}"
echo "=================================================="

# 1) 디렉토리 준비
sudo mkdir -p "${RELEASES_DIR}" "${LOGS_DIR}"
sudo chown -R deploy:deploy "${APP_DIR}"

# 2) 이미 같은 RELEASE_NAME이 있으면 중단 (idempotent 보호)
if [ -d "${RELEASE_DIR}" ]; then
    echo "Release ${RELEASE_NAME} 이미 존재. 다운로드 단계 스킵."
else
    mkdir -p "${RELEASE_DIR}"

    # 3) JAR 다운로드
    echo "Downloading JAR..."
    curl -fsS -u "${NEXUS_USER}:${NEXUS_PASS}" -o "${RELEASE_DIR}/app.jar" "${ARTIFACT_URL}"

    # 4) SHA256 체크섬 검증 (Nexus가 자동 생성)
    echo "Verifying SHA256..."
    EXPECTED_SHA=$(curl -fsS -u "${NEXUS_USER}:${NEXUS_PASS}" "${SHA_URL}" | awk '{print $1}')
    ACTUAL_SHA=$(sha256sum "${RELEASE_DIR}/app.jar" | awk '{print $1}')
    if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
        echo "SHA256 mismatch!"
        echo "  expected: ${EXPECTED_SHA}"
        echo "  actual  : ${ACTUAL_SHA}"
        rm -rf "${RELEASE_DIR}"
        exit 1
    fi
    echo "SHA256 OK: ${ACTUAL_SHA}"
fi

# 5) systemd unit 갱신 (RELEASE_NAME / ENV_NAME / TEAM 치환)
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

# 6) symlink 교체 (atomic)
sudo ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}.new"
sudo mv -Tf "${CURRENT_LINK}.new" "${CURRENT_LINK}"

# 7) 서비스 재시작
sudo systemctl enable "${APP}.service" 2>/dev/null || true
sudo systemctl restart "${APP}.service"

# 8) 오래된 release 정리 (최근 3개만 유지)
KEEP=3
cd "${RELEASES_DIR}"
ls -1t | tail -n +$((KEEP + 1)) | xargs -r rm -rf
echo "Kept ${KEEP} releases, removed older ones."

# 9) Health check
HEALTH_URL="http://localhost:8080/actuator/health"
echo "Health check: ${HEALTH_URL}"
for i in $(seq 1 12); do
    if curl -fsS --max-time 3 "${HEALTH_URL}" | grep -q '"status":"UP"' 2>/dev/null; then
        echo "Health OK (attempt ${i})"
        echo "DEPLOY SUCCESS: ${APP} ${RELEASE_NAME} → ${ENV_NAME}"
        exit 0
    fi
    echo "Waiting for health... (${i}/12)"
    sleep 5
done

echo "Health check 실패"
exit 1
