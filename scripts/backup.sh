#!/bin/bash
# backup.sh — CI/CD 코어 서비스 데이터 백업
#
# 대상: ldap / jenkins / nexus / rundeck / svn
# 방식:
#   - LDAP : slapcat 으로 디렉터리를 LDIF 로 추출 (논리 백업, 복원이 안정적)
#   - 그 외 : 데이터 디렉터리를 tar.gz 로 아카이브
#            (named 볼륨은 docker exec 로 컨테이너 내부에서 tar)
#
# 보관 정책: BACKUP_DIR 아래 타임스탬프 디렉터리로 저장, RETENTION_DAYS(기본 7일) 경과분 삭제
#
# 사용:
#   ./backup.sh                    # 전체 서비스 백업
#   RETENTION_DAYS=14 ./backup.sh  # 보관일 변경
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── 설정 ──────────────────────────────────────────────────────────────────────
BACKUP_ROOT="${BACKUP_ROOT:-${PROJECT_ROOT}/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEST="${BACKUP_ROOT}/${TIMESTAMP}"

# 컨테이너 이름 (compose 의 container_name 과 일치)
LDAP_CONTAINER="ldap"
JENKINS_CONTAINER="jenkins"
NEXUS_CONTAINER="nexus"
RUNDECK_CONTAINER="rundeck"

# named 볼륨 내부 데이터 경로 (컨테이너 기준)
JENKINS_DATA_PATH="/var/jenkins_home"
NEXUS_DATA_PATH="/nexus-data"
RUNDECK_DATA_PATH="/home/rundeck/server/data"

# SVN 은 바인드 마운트라 호스트에서 직접 접근
SVN_REPOS_DIR="${PROJECT_ROOT}/cicd/svn/repos"

# LDAP slapcat 설정 (osixia/openldap 기준)
LDAP_BASE_DN="${LDAP_BASE_DN:-}"

# ── 유틸 ──────────────────────────────────────────────────────────────────────
log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }

container_running() {
    docker ps --format '{{.Names}}' | grep -qx "$1"
}

# 실행 중인 컨테이너의 디렉터리를 호스트로 tar.gz 백업
backup_container_dir() {
    local container="$1" path="$2" outfile="$3"
    if ! container_running "${container}"; then
        fail "${container} 미실행 — 건너뜀"
        return 1
    fi
    log "  ${container}:${path} → $(basename "${outfile}")"
    docker exec "${container}" tar czf - -C "$(dirname "${path}")" "$(basename "${path}")" \
        > "${outfile}"
}

# ── 시작 ──────────────────────────────────────────────────────────────────────
log "=================================================="
log "BACKUP 시작 — ${DEST}"
log "=================================================="
mkdir -p "${DEST}"

FAILED=0

# 1) LDAP — slapcat 로 LDIF 추출
log "[1/5] LDAP (slapcat)"
if container_running "${LDAP_CONTAINER}"; then
    if docker exec "${LDAP_CONTAINER}" slapcat -n 1 > "${DEST}/ldap-data.ldif" 2>/dev/null; then
        log "  ldap-data.ldif 생성"
    else
        if docker exec "${LDAP_CONTAINER}" slapcat > "${DEST}/ldap-data.ldif" 2>/dev/null; then
            log "  ldap-data.ldif 생성 (full)"
        else
            fail "LDAP slapcat 실패"; FAILED=1
        fi
    fi
else
    fail "${LDAP_CONTAINER} 미실행 — 건너뜀"; FAILED=1
fi

# 2) Jenkins
log "[2/5] Jenkins (tar)"
backup_container_dir "${JENKINS_CONTAINER}" "${JENKINS_DATA_PATH}" \
    "${DEST}/jenkins_home.tar.gz" || FAILED=1

# 3) Nexus
log "[3/5] Nexus (tar)"
backup_container_dir "${NEXUS_CONTAINER}" "${NEXUS_DATA_PATH}" \
    "${DEST}/nexus_data.tar.gz" || FAILED=1

# 4) Rundeck
log "[4/5] Rundeck (tar)"
backup_container_dir "${RUNDECK_CONTAINER}" "${RUNDECK_DATA_PATH}" \
    "${DEST}/rundeck_data.tar.gz" || FAILED=1

# 5) SVN — 바인드 마운트 디렉터리 tar (운영은 rsync)
log "[5/5] SVN (tar)"
if [ -d "${SVN_REPOS_DIR}" ]; then
    tar czf "${DEST}/svn_repos.tar.gz" -C "$(dirname "${SVN_REPOS_DIR}")" \
        "$(basename "${SVN_REPOS_DIR}")"
    log "  svn_repos.tar.gz 생성"
else
    fail "SVN repos 디렉터리 없음: ${SVN_REPOS_DIR}"; FAILED=1
fi

# ── 매니페스트 ────────────────────────────────────────────────────────────────
{
    echo "backup_time=${TIMESTAMP}"
    echo "host=$(hostname)"
    echo "files:"
    ( cd "${DEST}" && ls -la )
} > "${DEST}/MANIFEST.txt"

# ── 보관 정책 적용 ────────────────────────────────────────────────────────────
log "보관 정책: ${RETENTION_DAYS}일 경과 백업 삭제"
if [ -d "${BACKUP_ROOT}" ]; then
    find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d \
        -mtime +"${RETENTION_DAYS}" -print -exec rm -rf {} + \
        | while read -r d; do log "  삭제: $(basename "${d}")"; done || true
fi

# ── 결과 ──────────────────────────────────────────────────────────────────────
log "=================================================="
if [ "${FAILED}" -eq 0 ]; then
    log "BACKUP 완료 — ${DEST}"
    log "=================================================="
    exit 0
else
    fail "BACKUP 일부 실패 — ${DEST} 확인 필요"
    log "=================================================="
    exit 1
fi
