#!/bin/bash
# restore.sh — backup.sh 산출물로부터 코어 서비스 데이터 복원
#
# 대상: ldap / jenkins / nexus / rundeck / svn
# 역매핑(백업 → 복원):
#   ldap-data.ldif      → slapadd  (slapcat 의 짝)
#   jenkins_home.tar.gz → /var/jenkins_home 에 전개
#   nexus_data.tar.gz   → /nexus-data 에 전개
#   rundeck_data.tar.gz → /home/rundeck/server/data 에 전개
#   svn_repos.tar.gz    → cicd/svn/repos 에 전개 (바인드 마운트)
#
# 안전장치:
#   - 복원은 기존 데이터를 덮어쓰는 파괴적 작업이므로 실행 전 확인을 받는다.
#   - 대상 서비스를 중지한 뒤 복원하고 다시 기동한다(정합성 보호).
#   - 특정 서비스만 부분 복원할 수 있다.
#
# 사용:
#   ./restore.sh <BACKUP_DIR>                 # 전체 복원
#   ./restore.sh <BACKUP_DIR> ldap jenkins    # 일부 서비스만 복원
#   ./restore.sh --list                       # 사용 가능한 백업 목록
#   FORCE=1 ./restore.sh <BACKUP_DIR>         # 확인 프롬프트 생략

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BACKUP_ROOT="${BACKUP_ROOT:-${PROJECT_ROOT}/backups}"
COMPOSE_FILE="${PROJECT_ROOT}/compose/cicd.yml"
ENV_FILE="${PROJECT_ROOT}/.env"
FORCE="${FORCE:-0}"

LDAP_CONTAINER="ldap"
JENKINS_CONTAINER="jenkins"
NEXUS_CONTAINER="nexus"
RUNDECK_CONTAINER="rundeck"

JENKINS_DATA_PATH="/var/jenkins_home"
NEXUS_DATA_PATH="/nexus-data"
RUNDECK_DATA_PATH="/home/rundeck/server/data"
SVN_REPOS_DIR="${PROJECT_ROOT}/cicd/svn/repos"

ALL_SERVICES=(ldap jenkins nexus rundeck svn)

log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }

dc() {
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -qx "$1"
}

list_backups() {
    log "사용 가능한 백업 (${BACKUP_ROOT}):"
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r
    else
        echo "  (백업 디렉터리 없음)"
    fi
}

# ── 인자 처리 ─────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--list" ]; then
    list_backups
    exit 0
fi

if [ $# -lt 1 ]; then
    fail "사용법: $0 <BACKUP_DIR> [service...]    (목록: $0 --list)"
    exit 1
fi

RAW_DIR="$1"; shift
if [ -d "${RAW_DIR}" ]; then
    BACKUP_DIR="$(cd "${RAW_DIR}" && pwd)"
elif [ -d "${BACKUP_ROOT}/${RAW_DIR}" ]; then
    BACKUP_DIR="${BACKUP_ROOT}/${RAW_DIR}"
else
    fail "백업 디렉터리를 찾을 수 없음: ${RAW_DIR}"
    list_backups
    exit 1
fi

if [ $# -gt 0 ]; then
    TARGETS=("$@")
    for s in "${TARGETS[@]}"; do
        if ! printf '%s\n' "${ALL_SERVICES[@]}" | grep -qx "${s}"; then
            fail "알 수 없는 서비스: ${s} (가능: ${ALL_SERVICES[*]})"
            exit 1
        fi
    done
else
    TARGETS=("${ALL_SERVICES[@]}")
fi

# ── 확인 ──────────────────────────────────────────────────────────────────────
log "=================================================="
log "RESTORE"
log "  백업원본 : ${BACKUP_DIR}"
log "  대상서비스: ${TARGETS[*]}"
log "=================================================="
log "주의: 대상 서비스의 기존 데이터를 덮어씁니다 (되돌릴 수 없음)."

if [ "${FORCE}" != "1" ]; then
    read -r -p "계속하시겠습니까? (yes 입력 시 진행) " ans
    if [ "${ans}" != "yes" ]; then
        log "취소되었습니다."
        exit 0
    fi
fi

restore_container_tar() {
    local container="$1" path="$2" archive="$3"
    if [ ! -f "${archive}" ]; then
        fail "  아카이브 없음: ${archive} — 건너뜀"; return 1
    fi
    if ! container_running "${container}"; then
        fail "  ${container} 미실행(중지 상태에서 데이터만 복원 불가) — 건너뜀"; return 1
    fi
    log "  ${archive##*/} → ${container}:${path}"
    docker exec "${container}" sh -c "rm -rf '${path}'/* '${path}'/.[!.]* 2>/dev/null || true"
    docker exec -i "${container}" tar xzf - -C "$(dirname "${path}")" < "${archive}"
}

restore_one() {
    local svc="$1"
    case "${svc}" in
        ldap)
            local ldif="${BACKUP_DIR}/ldap-data.ldif"
            [ -f "${ldif}" ] || { fail "  ldap-data.ldif 없음 — 건너뜀"; return 1; }
            log "[ldap] slapadd 로 복원"
            docker exec -i "${LDAP_CONTAINER}" sh -c '
                rm -rf /var/lib/ldap/*;
                slapadd -n 1 -l /dev/stdin;
            ' < "${ldif}" 2>/dev/null \
                && log "  LDIF 적재 완료" \
                || fail "  slapadd 실패 (이미지 구조 확인 필요)"
            dc restart ldap >/dev/null 2>&1 || true
            ;;
        jenkins)
            log "[jenkins] tar 복원"
            restore_container_tar "${JENKINS_CONTAINER}" "${JENKINS_DATA_PATH}" \
                "${BACKUP_DIR}/jenkins_home.tar.gz" || true
            dc restart jenkins >/dev/null 2>&1 || true
            ;;
        nexus)
            log "[nexus] tar 복원"
            restore_container_tar "${NEXUS_CONTAINER}" "${NEXUS_DATA_PATH}" \
                "${BACKUP_DIR}/nexus_data.tar.gz" || true
            dc restart nexus >/dev/null 2>&1 || true
            ;;
        rundeck)
            log "[rundeck] tar 복원"
            restore_container_tar "${RUNDECK_CONTAINER}" "${RUNDECK_DATA_PATH}" \
                "${BACKUP_DIR}/rundeck_data.tar.gz" || true
            dc restart rundeck >/dev/null 2>&1 || true
            ;;
        svn)
            local archive="${BACKUP_DIR}/svn_repos.tar.gz"
            [ -f "${archive}" ] || { fail "  svn_repos.tar.gz 없음 — 건너뜀"; return 1; }
            log "[svn] tar 복원 (바인드 마운트)"
            dc stop svn >/dev/null 2>&1 || true
            sudo rm -rf "${SVN_REPOS_DIR:?}"/*
            sudo tar xzf "${archive}" -C "$(dirname "${SVN_REPOS_DIR}")"
            sudo chown -R www-data:www-data "${SVN_REPOS_DIR:?}"
            log "  svn repos 전개 완료"
            dc start svn >/dev/null 2>&1 || true
            ;;
    esac
}

FAILED=0
for svc in "${TARGETS[@]}"; do
    restore_one "${svc}" || FAILED=1
done

log "=================================================="
if [ "${FAILED}" -eq 0 ]; then
    log "RESTORE 완료 — 서비스 상태를 확인하세요 (docker compose ps)"
else
    fail "RESTORE 일부 실패 — 로그 확인 필요"
fi
log "=================================================="
[ "${FAILED}" -eq 0 ]
