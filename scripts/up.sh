#!/bin/bash
# up.sh — 올바른 순서로 스택 기동
#
# 순서
#  [0/3] build.yml    → node/java/python base image 생성
#  [1/3] cicd.yml     → cicd-net 생성
#  [2/3] observability/nodes/agents 기동
#
# 사용:
#   ./up.sh
#   ./up.sh core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

COMPOSE_DIR="${PROJECT_ROOT}/compose"
ENV_FILE="${PROJECT_ROOT}/.env"

# core만 기동
if [ "${1:-}" = "core" ]; then
    echo "core만 기동..."

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_DIR}/cicd.yml" \
      up -d

    echo
    echo "완료. (cicd-net 생성)"

    docker network ls | grep cicd-net && echo "cicd-net OK"

    exit 0
fi

##################################################
# [0/3] Node Base Image Build
##################################################

if [ -f "${COMPOSE_DIR}/build.yml" ]; then

    echo "[0/3] node base image 확인..."

    NEED_BUILD=false

    docker image inspect cicd-node-react:1.0 >/dev/null 2>&1 || NEED_BUILD=true
    docker image inspect cicd-node-java:1.0 >/dev/null 2>&1 || NEED_BUILD=true
    docker image inspect cicd-node-python:1.0 >/dev/null 2>&1 || NEED_BUILD=true

    if [ "${NEED_BUILD}" = true ]; then

        echo "[0/3] node base image build..."

        docker compose \
          --env-file "${ENV_FILE}" \
          -f "${COMPOSE_DIR}/build.yml" \
          build

    else

        echo "[0/3] node base image already exists"

    fi

fi

##################################################
# 보조 레이어 자동 수집
##################################################

EXTRA=()

for f in \
  "${COMPOSE_DIR}/observability.yml" \
  "${COMPOSE_DIR}/nodes.yml" \
  "${COMPOSE_DIR}/agents.yml"
do
    [ -f "$f" ] && EXTRA+=(-f "$f")
done

##################################################
# [1/3] core 기동
##################################################

echo "[1/3] core 기동 — cicd-net 생성..."

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${COMPOSE_DIR}/cicd.yml" \
  up -d

##################################################
# [2/3] 보조 레이어 기동
##################################################

if [ ${#EXTRA[@]} -gt 0 ]; then

    echo "[2/3] 보조 레이어 기동 (${EXTRA[*]})..."

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${COMPOSE_DIR}/cicd.yml" \
      "${EXTRA[@]}" \
      up -d

fi

##################################################
# 상태 출력
##################################################

echo
echo "=================================================="

docker network ls | grep cicd-net && echo "cicd-net OK"

echo "=================================================="

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${COMPOSE_DIR}/cicd.yml" \
  "${EXTRA[@]}" \
  ps
