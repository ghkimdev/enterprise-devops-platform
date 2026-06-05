#!/bin/bash
# down.sh — 스택 정지 (up.sh와 대칭)
#
# 사용:
#   ./down.sh             # 컨테이너만 정지/제거 (볼륨·데이터 보존)
#   ./down.sh --volumes   # 볼륨까지 삭제 (Jenkins/Nexus/LDAP 데이터 전부 소멸 — 확인 받음)
#
# 주의: cicd-net은 보조 레이어가 external로 참조하므로, 전부 같은 -f 묶음으로 내려야
#       네트워크 제거 시 경고 없이 깔끔하게 정리된다.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_DIR="${PROJECT_ROOT}/compose"
ENV_FILE="${PROJECT_ROOT}/.env"

# 존재하는 보조 레이어 자동 수집
EXTRA=()
for f in \
  "${COMPOSE_DIR}/observability.yml" \
  "${COMPOSE_DIR}/nodes.yml" \
  "${COMPOSE_DIR}/agents.yml"
do
    [ -f "$f" ] && EXTRA+=(-f "$f")
done

DOWN_ARGS=(--remove-orphans)

if [ "${1:-}" = "--volumes" ] || [ "${1:-}" = "-v" ]; then
    echo "⚠️  볼륨까지 삭제합니다 — Jenkins/Nexus/LDAP/Grafana 등 모든 데이터가 사라집니다."
    read -r -p "정말 진행하시겠습니까? (yes 입력 시 진행): " ans
    if [ "${ans}" = "yes" ]; then
        DOWN_ARGS+=(--volumes)
    else
        echo "취소했습니다. 컨테이너만 정지합니다 (볼륨 보존)."
    fi
fi

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${COMPOSE_DIR}/cicd.yml" \
  "${EXTRA[@]}" \
  down \
  "${DOWN_ARGS[@]}"

echo -e "\n정지 완료."
if printf '%s\n' "${DOWN_ARGS[@]}" | grep -q -- '--volumes'; then
    echo "볼륨도 삭제됨 — 다음 기동 시 Jenkins/Nexus 등 초기 설정부터 다시 진행됩니다."
fi
