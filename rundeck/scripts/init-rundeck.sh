#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

PROJECT_NAME="sample"

export RD_URL="${RD_URL:-https://rundeck.example.com}"
export RD_USER="${RD_USER:-admin}"
export RD_PASSWORD="${RD_PASSWORD:-admin}"

export RD_TOKEN=$(rd tokens create -u admin -r * | tail -n 1)

PROJECT_DIR="${BASE_DIR}/projects/${PROJECT_NAME}"
JOB_DIR="${PROJECT_DIR}/jobs"

KEY_PATH="${BASE_DIR}/keys/project/${PROJECT_NAME}/deploy-key"
KEY_STORAGE_PATH="keys/project/${PROJECT_NAME}/deploy-key"

log() {
    echo "[rundeck-bootstrap] $1"
}

project_exists() {
    rd projects info -p "$PROJECT_NAME" >/dev/null 2>&1
}

key_exists() {
    rd keys info -p "$KEY_STORAGE_PATH" >/dev/null 2>&1
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
    log "Applying project.properties..."

    rd projects configure update \
        -p "${PROJECT_NAME}" \
        -f "${PROJECT_DIR}/etc/project.properties"

    log "Project configuration applied"
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

verify_api() {
    log "Checking Rundeck API..."

    rd system info >/dev/null

    log "Rundeck API reachable"
}

main() {
    verify_api

    ensure_project

    configure_project_resources

    ensure_key

    import_jobs

    log "Provision completed successfully"
}

main
