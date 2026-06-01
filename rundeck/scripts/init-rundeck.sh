#!/bin/bash

set -euo pipefail

export RD_URL="${RUNDECK_GRAILS_URL}"
export RD_USER="${LDAP_ADMIN_USER}"
export RD_PASSWORD="${LDAP_BIND_PASSWORD}"
#export RD_INSECURE="${RD_INSECURE:-true}"

PROJECT_NAME="sample"
PROJECT_DIR="/home/rundeck/projects/${PROJECT_NAME}"
JOB_DIR="${PROJECT_DIR}/jobs"

KEY_PATH="/home/rundeck/keys/project/${PROJECT_NAME}/deploy-key"
KEY_STORAGE_PATH="keys/project/${PROJECT_NAME}/deploy-key"

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
RD_TOKEN=$(rd tokens create \
    -u "${RD_USER}" \
    -r '*' \
    | tail -n 1)

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
rd keys list 2>/dev/null | grep -Fq "${KEY_STORAGE_PATH}"
}

ensure_key() {
if [[ ! -f "${KEY_PATH}" ]]; then
log "SSH key not found: ${KEY_PATH}"
return
fi

if key_exists; then
    log "SSH key already exists: ${KEY_STORAGE_PATH}"
    return
fi

log "Importing SSH key..."

rd keys create \
    -t privateKey \
    -f "${KEY_PATH}" \
    -p "${KEY_STORAGE_PATH}"

log "SSH key imported"

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

main() {
wait_for_rundeck

create_token

ensure_project

configure_project_resources

ensure_key

import_jobs

log "Provision completed successfully"

}

main

