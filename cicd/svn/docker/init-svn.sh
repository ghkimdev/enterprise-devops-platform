#!/bin/bash
#
# init-svn.sh — SVN 저장소 부트스트랩 (docker compose 기동 시 실행)
#
# 개선점 (이전 버전 대비):
#   1) "저장소 생성"과 "훅 설치"를 분리했다.
#      - 저장소 생성: db 디렉토리가 없을 때만 (멱등, 1회)
#      - 훅 설치    : 매 기동마다 항상 덮어쓴다 (훅을 수정해도 즉시 반영되도록)
#        ※ 이전 버전은 훅 설치가 생성 블록 안에 있어, 한 번 만들어진 저장소는
#          훅을 고쳐도 영영 갱신되지 않는 함정이 있었다.
#   2) post-commit 은 앱/팀을 self-discovery 하는 단일 스크립트라
#      저장소마다 다른 파일을 둘 필요가 없다 (모든 repo에 동일 파일 복사).
#   3) 공통 동작을 함수로 묶고 로그 prefix 를 붙여 디버깅을 쉽게 했다.

set -euo pipefail

HOOKS_SRC="/hooks"
REPOS_ROOT="/var/svn/repos"
SEED_ROOT="/seed"
SVN_OWNER="www-data:www-data"

log() { echo "[init-svn] $*"; }

# ──────────────────────────────────────────────
# 저장소 루트 디렉토리 준비 (멱등).
#   svnadmin create 는 부모 디렉토리가 없으면 실패하므로 먼저 보장한다.
# ──────────────────────────────────────────────
log "저장소 루트 준비: ${REPOS_ROOT}"
mkdir -p "${REPOS_ROOT}"
chown "${SVN_OWNER}" "${REPOS_ROOT}"
chmod 755 "${REPOS_ROOT}"

# ──────────────────────────────────────────────
# 훅 로그 디렉토리 준비 (멱등).
#   훅은 apache(www-data)가 실행하므로 www-data 가 쓸 수 있어야 한다.
#   호스트에서 보려면 compose 에서 ./svn/logs:/var/log/svn-hooks 마운트 권장.
# ──────────────────────────────────────────────
HOOK_LOG_DIR="/var/log/svn-hooks"
log "훅 로그 디렉토리 준비: ${HOOK_LOG_DIR}"
mkdir -p "${HOOK_LOG_DIR}"
chown "${SVN_OWNER}" "${HOOK_LOG_DIR}"
chmod 755 "${HOOK_LOG_DIR}"

# ──────────────────────────────────────────────
# 저장소 생성 (없을 때만). 멱등.
#   $1 = repo 이름 (= seed 디렉토리명)
#   $2 = repo 경로
#   $3 = "with_initial_tag" 면 tags/r-initial 생성 (checkitem BASE_TAG 기준점)
# ──────────────────────────────────────────────
create_repo() {
    local repo="$1" repo_path="$2" opt="${3:-}"

    if [ -d "${repo_path}/db" ]; then
        log "${repo}: 이미 존재함 → 생성 건너뜀"
        return 0
    fi

    log "${repo}: 저장소 생성"
    svnadmin create "${repo_path}"
    chown -R "${SVN_OWNER}" "${repo_path}"

    log "${repo}: trunk/branches/tags 레이아웃 초기화"
    svn mkdir -q \
        "file://${repo_path}/trunk" \
        "file://${repo_path}/branches" \
        "file://${repo_path}/tags" \
        -m "Initialize layout"

    # checkitem 의 BASE_TAG(ListSubversionTags)가 고를 최초 기준 태그
    if [ "${opt}" = "with_initial_tag" ]; then
        log "${repo}: 초기 태그 r-initial 생성"
        svn mkdir -q \
            "file://${repo_path}/tags/r-initial" \
            -m "Add initial tag"
    fi

    if [ -d "${SEED_ROOT}/${repo}" ]; then
        log "${repo}: seed import"
        # 주의: 이 import 는 훅 설치 '이전'에 일어나므로 post-commit 알림이 발생하지 않는다.
        svn import -q "${SEED_ROOT}/${repo}" \
            "file://${repo_path}/trunk" \
            -m "Initial repository structure"
    else
        log "${repo}: seed 없음(${SEED_ROOT}/${repo}) → import 생략"
    fi
}

# ──────────────────────────────────────────────
# 훅 설치. 항상 덮어쓴다 (매 기동 멱등).
#   $1      = repo 경로
#   $2..    = 설치할 훅 이름들
# ──────────────────────────────────────────────
install_hooks() {
    local repo_path="$1"; shift
    local hooks=("$@")
    local h

    for h in "${hooks[@]}"; do
        if [ -f "${HOOKS_SRC}/${h}" ]; then
            cp "${HOOKS_SRC}/${h}" "${repo_path}/hooks/${h}"
            chmod +x "${repo_path}/hooks/${h}"
            chown "${SVN_OWNER}" "${repo_path}/hooks/${h}"
        else
            log "경고: 훅 소스 없음 → ${HOOKS_SRC}/${h} (건너뜀)"
        fi
    done
    log "$(basename "${repo_path}"): 훅 설치 완료 (${hooks[*]})"
}

# ══════════════════════════════════════════════
# 애플리케이션 저장소
# ══════════════════════════════════════════════
for repo in sample-spring sample-react sample-fastapi; do
    repo_path="${REPOS_ROOT}/${repo}"
    create_repo  "${repo}" "${repo_path}" with_initial_tag
    install_hooks "${repo_path}" pre-commit 
done

# ══════════════════════════════════════════════
# Jenkins Shared Library 저장소
#   (start-commit 동결 훅까지 포함)
# ══════════════════════════════════════════════
SHARED="cicd-shared-library"
SHARED_PATH="${REPOS_ROOT}/${SHARED}"
create_repo  "${SHARED}" "${SHARED_PATH}"
install_hooks "${SHARED_PATH}" pre-commit

log "SVN bootstrap 완료"
