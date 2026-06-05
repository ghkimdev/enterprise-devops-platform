#!/bin/bash
# up.sh — 올바른 순서로 스택 기동
#
# 핵심: core(docker-compose.yml)가 cicd-net을 "생성"하고,
#       보조 레이어(observability/nodes/agents)는 external로 "참조"한다.
#       그래서 반드시 core를 먼저 띄워 네트워크를 만든 뒤 레이어를 얹어야 한다.
#       (모든 -f를 한 번에 주면 external 선언이 병합돼 네트워크 생성이 무력화됨)
#
# 사용:
#   ./up.sh          # core + 존재하는 모든 보조 레이어
#   ./up.sh core     # core만 (메모리 절약)

set -euo pipefail
cd "$(dirname "$0")"

# core만 기동
if [ "${1:-}" = "core" ]; then
    echo "core만 기동..."
    docker compose up -d
    echo -e "\n완료. (cicd-net 생성)"
    docker network ls | grep cicd-net && echo "cicd-net OK"
    exit 0
fi

# 존재하는 보조 레이어 자동 수집
EXTRA=()
for f in docker-compose.observability.yml docker-compose.nodes.yml docker-compose.agents.yml; do
    [ -f "$f" ] && EXTRA+=(-f "$f")
done

# 1) core 먼저 — cicd-net 생성
echo "[1/2] core 기동 — cicd-net 생성..."
docker compose up -d

# 2) 보조 레이어 — 이제 cicd-net이 존재하므로 external 참조가 해석됨
if [ ${#EXTRA[@]} -gt 0 ]; then
    echo "[2/2] 보조 레이어 기동 (${EXTRA[*]})..."
    docker compose -f docker-compose.yml "${EXTRA[@]}" up -d
fi

echo -e "\n=================================================="
docker network ls | grep cicd-net && echo "cicd-net OK"
echo "=================================================="
docker compose -f docker-compose.yml "${EXTRA[@]}" ps
