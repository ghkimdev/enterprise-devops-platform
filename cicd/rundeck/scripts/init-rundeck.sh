#!/bin/bash

set -euo pipefail
export RD_URL="${RUNDECK_GRAILS_URL}"
export RD_USER="${LDAP_ADMIN_USER}"
export RD_PASSWORD="${LDAP_BIND_PASSWORD}"
PROJECT_NAME="sample"
PROJECT_DIR="/home/rundeck/projects/${PROJECT_NAME}"
JOB_DIR="${PROJECT_DIR}/jobs"
ACL_DIR="${PROJECT_DIR}/etc/aclpolicy"
KEY_PATH="/home/rundeck/keys/project/${PROJECT_NAME}/deploy-key"
KEY_STORAGE_PATH="keys/project/${PROJECT_NAME}/deploy-key"
NEXUS_USER_STORAGE_PATH="keys/project/${PROJECT_NAME}/nexus-user"
NEXUS_PASS_STORAGE_PATH="keys/project/${PROJECT_NAME}/nexus-pass"
log() {
    echo "[rundeck-bootstrap] $1"
}
wait_for_rundeck() {
    log "Waiting for Rundeck API..."
    until rd system info >/dev/null 2>&1
    do
        sleep 5
    done
    log "Rundeck API reachable"
}
create_token() {
    if [[ -n "${RD_TOKEN:-}" ]]; then
        log "Using existing RD_TOKEN"
        return
    fi
    log "Creating bootstrap token..."
    export RD_TOKEN
    RD_TOKEN=$(
        rd tokens create \
            -u "${RD_USER}" \
            -r '*' \
        | tail -n 1
    )
    log "Token created"
}
project_exists() {
    rd projects info -p "${PROJECT_NAME}" >/dev/null 2>&1
}
ensure_project() {
    if project_exists; then
        log "Project already exists: ${PROJECT_NAME}"
        return
    fi
    log "Creating project: ${PROJECT_NAME}"
    rd projects create \
        -p "${PROJECT_NAME}"
    log "Project created"
}
configure_project_resources() {
    local config_file="${PROJECT_DIR}/etc/project.properties"
    if [[ ! -f "${config_file}" ]]; then
        log "project.properties not found: ${config_file}"
        return
    fi
    log "Applying project configuration..."
    rd projects configure update \
        -p "${PROJECT_NAME}" \
        -f "${config_file}"
    log "Project configuration applied"
}
key_exists() {
    local path="$1"
    rd keys info -p "${path}" >/dev/null 2>&1
}
ensure_deploy_key() {
    if [[ ! -f "${KEY_PATH}" ]]; then
        log "SSH key not found: ${KEY_PATH}"
        return
    fi
    if key_exists "${KEY_STORAGE_PATH}"; then
        log "SSH key already exists: ${KEY_STORAGE_PATH}"
        return
    fi
    log "Importing deploy SSH key..."
    rd keys create \
        -t privateKey \
        -f "${KEY_PATH}" \
        -p "${KEY_STORAGE_PATH}"
    log "SSH key imported"
}
ensure_password_key() {
    local storage_path="$1"
    local value="$2"
    local description="$3"
    if key_exists "${storage_path}"; then
        log "${description} already exists"
        return
    fi
    log "Creating ${description}..."
    local tmp
    tmp=$(mktemp)
    printf '%s' "${value}" > "${tmp}"
    rd keys create \
        -t password \
        -f "${tmp}" \
        -p "${storage_path}"
    rm -f "${tmp}"
    log "${description} created"
}
ensure_nexus_credentials() {
    ensure_password_key \
        "${NEXUS_USER_STORAGE_PATH}" \
        "${LDAP_ADMIN_USER}" \
        "Nexus user key"
    ensure_password_key \
        "${NEXUS_PASS_STORAGE_PATH}" \
        "${LDAP_BIND_PASSWORD}" \
        "Nexus password key"
}
import_jobs() {
    if [[ ! -d "${JOB_DIR}" ]]; then
        log "Job directory not found: ${JOB_DIR}"
        return
    fi
    log "Importing jobs..."
    for job in "${JOB_DIR}"/*.yaml
    do
        [[ -f "$job" ]] || continue
        log "Loading job: $job"
        rd jobs load \
            -p "${PROJECT_NAME}" \
            -f "$job" \
            --format yaml \
            --duplicate update
    done
    log "Jobs imported"
}
apply_acl_policy() {
    # $1: scope (system|project), $2: policy name, $3: file path
    local scope="$1"
    local name="$2"
    local file="$3"
    if [[ ! -f "${file}" ]]; then
        log "ACL file not found: ${file}"
        return
    fi
    # create 실패(이미 존재) 시 update 로 대체 → 재실행 안전(멱등)
    if [[ "${scope}" == "system" ]]; then
        log "Applying system ACL: ${name}"
        rd system acls create -n "${name}" -f "${file}" >/dev/null 2>&1 \
            || rd system acls update -n "${name}" -f "${file}"
    else
        log "Applying project ACL: ${name}"
        rd projects acls create -p "${PROJECT_NAME}" -n "${name}" -f "${file}" >/dev/null 2>&1 \
            || rd projects acls update -p "${PROJECT_NAME}" -n "${name}" -f "${file}"
    fi
    log "ACL applied: ${name}"
}
apply_acls() {
    if [[ ! -d "${ACL_DIR}" ]]; then
        log "ACL directory not found: ${ACL_DIR}"
        return
    fi
    log "Applying ACL policies from ${ACL_DIR}"
    # 시스템 ACL: 세 팀 모두 sample 프로젝트 접근(read)
    apply_acl_policy system  "sample-access.aclpolicy"   "${ACL_DIR}/sample-access.aclpolicy"
    # 프로젝트 ACL: 팀별 잡/노드 권한
    apply_acl_policy project "ml-team.aclpolicy"          "${ACL_DIR}/ml-team.aclpolicy"
    apply_acl_policy project "web-team.aclpolicy"         "${ACL_DIR}/web-team.aclpolicy"
    apply_acl_policy project "payment-team.aclpolicy"     "${ACL_DIR}/payment-team.aclpolicy"
    log "ACL policies applied"
}
main() {
    wait_for_rundeck
    create_token
    ensure_project
    configure_project_resources
    ensure_deploy_key
    ensure_nexus_credentials
    import_jobs
    apply_acls
    log "Provision completed successfully"
}
main
