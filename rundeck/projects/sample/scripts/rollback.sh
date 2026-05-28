#!/bin/bash
# rollback.sh — 공통 롤백 스크립트
#
# 환경변수:
#   APP=sample-react|sample-spring|sample-fastapi
#   ENV_NAME=dev|stg|prod
#   TEAM
#   TARGET_RELEASE=                                # 빈 값이면 직전 release로
#   APP_DIR_BASE=/opt|/var/www                     # spring/fastapi는 /opt, react는 /var/www
#
# 롤백은 단순히 current symlink만 옮기고 (react는 docroot 링크도) 서비스를 재시작.

set -euo pipefail

: "${APP:?APP required}"
: "${ENV_NAME:?ENV_NAME required}"
: "${TEAM:=unknown}"
TARGET_RELEASE="${TARGET_RELEASE:-}"

case "${APP}" in
    sample-react)
        APP_DIR="/var/www/${APP}"
        SERVICE=""            # nginx만 reload
        DOCROOT="/var/www/html/${APP}"
        ;;
    sample-spring)
        APP_DIR="/opt/${APP}"
        SERVICE="${APP}.service"
        DOCROOT=""
        ;;
    sample-fastapi)
        APP_DIR="/opt/${APP}"
        SERVICE="${APP}.service"
        DOCROOT=""
        ;;
    *)
        echo "Unknown APP: ${APP}"
        exit 1
        ;;
esac

RELEASES_DIR="${APP_DIR}/releases"
CURRENT_LINK="${APP_DIR}/current"

echo "=================================================="
echo "ROLLBACK ${APP} → ${ENV_NAME}"
echo "=================================================="
echo "TEAM             : ${TEAM}"
echo "TARGET_RELEASE   : ${TARGET_RELEASE:-(previous)}"
echo "=================================================="

if [ ! -d "${RELEASES_DIR}" ]; then
    echo "${RELEASES_DIR} 없음"
    exit 1
fi

cd "${RELEASES_DIR}"
RELEASES=( $(ls -1t) )
if [ "${#RELEASES[@]}" -lt 2 ]; then
    echo "롤백할 이전 release가 없습니다. 현재 보유 release 수: ${#RELEASES[@]}"
    exit 1
fi

CURRENT_RELEASE=$(basename "$(readlink -f "${CURRENT_LINK}")")

# Target 결정
if [ -n "${TARGET_RELEASE}" ]; then
    if [ ! -d "${RELEASES_DIR}/${TARGET_RELEASE}" ]; then
        echo "TARGET_RELEASE ${TARGET_RELEASE} 가 ${RELEASES_DIR}에 없음"
        echo "보관된 releases:"
        ls -1t
        exit 1
    fi
    TARGET="${TARGET_RELEASE}"
else
    # 현재가 아닌 것 중 가장 최신
    for r in "${RELEASES[@]}"; do
        if [ "${r}" != "${CURRENT_RELEASE}" ]; then
            TARGET="${r}"
            break
        fi
    done
fi

if [ -z "${TARGET:-}" ]; then
    echo "롤백 target 결정 실패"
    exit 1
fi

echo "Current : ${CURRENT_RELEASE}"
echo "Target  : ${TARGET}"

# symlink 교체
sudo ln -sfn "${RELEASES_DIR}/${TARGET}" "${CURRENT_LINK}.new"
sudo mv -Tf "${CURRENT_LINK}.new" "${CURRENT_LINK}"

# 앱별 추가 처리
if [ "${APP}" = "sample-react" ]; then
    # docroot 재링크 + nginx reload
    sudo ln -sfn "${CURRENT_LINK}" "${DOCROOT}.new"
    sudo mv -Tf "${DOCROOT}.new" "${DOCROOT}"
    sudo systemctl reload nginx 2>/dev/null || true
    HEALTH_URL="http://localhost/healthz"
else
    # systemd 서비스 재시작 - systemd unit은 재배포 시 이미 갱신되어 있음
    # (롤백 대상 release가 자신이 배포될 때 unit을 썼으므로)
    # 단, RELEASE_NAME 환경변수가 변경되어야 하므로 unit을 다시 렌더링.
    TEMPLATE="/etc/${APP}/systemd.template"
    if [ -f "${TEMPLATE}" ]; then
        sudo sed \
            -e "s|__RELEASE_NAME__|${TARGET}|g" \
            -e "s|__ENV_NAME__|${ENV_NAME}|g" \
            -e "s|__TEAM__|${TEAM}|g" \
            "${TEMPLATE}" > /tmp/${APP}.service.tmp
        sudo mv /tmp/${APP}.service.tmp "/etc/systemd/system/${APP}.service"
        sudo systemctl daemon-reload
    fi
    sudo systemctl restart "${SERVICE}"

    if [ "${APP}" = "sample-spring" ]; then
        HEALTH_URL="http://localhost:8080/actuator/health"
        EXPECT_BODY='"status":"UP"'
    else
        HEALTH_URL="http://localhost:8000/healthz"
        EXPECT_BODY=""
    fi
fi

# Health check
echo "Health check: ${HEALTH_URL}"
for i in $(seq 1 12); do
    if [ -n "${EXPECT_BODY:-}" ]; then
        if curl -fsS --max-time 3 "${HEALTH_URL}" | grep -q "${EXPECT_BODY}"; then
            echo "Health OK (attempt ${i})"
            echo "ROLLBACK SUCCESS: ${APP} → ${TARGET}"
            exit 0
        fi
    else
        if curl -fsS --max-time 3 "${HEALTH_URL}" > /dev/null; then
            echo "Health OK (attempt ${i})"
            echo "ROLLBACK SUCCESS: ${APP} → ${TARGET}"
            exit 0
        fi
    fi
    echo "Waiting for health... (${i}/12)"
    sleep 5
done

echo "Health check 실패 (rollback 시도 후)"
exit 1
