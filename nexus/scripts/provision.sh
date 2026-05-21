#!/bin/sh
set -eu

# -----------------------------------------------------------------------------
# Nexus Bootstrap Provisioning Script
#
# Responsibilities
#   - Wait for Nexus startup
#   - Configure LDAP integration
#   - Create blob stores
#   - Create repositories
#   - Configure security realms
#   - Create Nexus roles
#
# Design Goals
#   - Idempotent
#   - Re-runnable
#   - CI/CD friendly
#   - Clear logging
# -----------------------------------------------------------------------------

NEXUS_URL="http://nexus:8081"
ADMIN_USER="admin"

# -----------------------------------------------------------------------------
# Wait for admin password initialization
# -----------------------------------------------------------------------------

echo "[INFO] Waiting for Nexus admin password..."

until [ -f /nexus-data/admin.password ]; do
    sleep 3
done

ADMIN_PASS=$(cat /nexus-data/admin.password)

# -----------------------------------------------------------------------------
# Wait for Nexus REST API readiness
# -----------------------------------------------------------------------------

echo "[INFO] Waiting for Nexus API..."

until curl -sf "${NEXUS_URL}/service/rest/v1/status" > /dev/null; do
    sleep 5
done

echo "[INFO] Nexus API is ready"

# -----------------------------------------------------------------------------
# Generic REST API wrapper
# -----------------------------------------------------------------------------

api_request() {
    local method=$1
    local endpoint=$2
    local payload=${3:-}

    echo "[INFO] ${method} ${endpoint}"

    if [ -n "${payload}" ]; then
        HTTP_CODE=$(curl -s \
            -o /tmp/response.json \
            -w "%{http_code}" \
            -u "${ADMIN_USER}:${ADMIN_PASS}" \
            -X "${method}" \
            -H "Content-Type: application/json" \
            "${NEXUS_URL}${endpoint}" \
            -d @"${payload}")
    else
        HTTP_CODE=$(curl -s \
            -o /tmp/response.json \
            -w "%{http_code}" \
            -u "${ADMIN_USER}:${ADMIN_PASS}" \
            -X "${method}" \
            "${NEXUS_URL}${endpoint}")
    fi

    case "${HTTP_CODE}" in
        200|201|204)
            echo "[SUCCESS] ${endpoint}"
            ;;

        409)
            echo "[SKIP] Resource already exists"
            ;;

        *)
            echo "[ERROR] Request failed (${HTTP_CODE})"

            if [ -s /tmp/response.json ]; then
                cat /tmp/response.json
            fi

            exit 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Resource existence checks
# -----------------------------------------------------------------------------

blobstore_exists() {
    curl -s \
        -u "${ADMIN_USER}:${ADMIN_PASS}" \
        "${NEXUS_URL}/service/rest/v1/blobstores" \
    | jq -e ".[] | select(.name == \"$1\")" > /dev/null
}

repository_exists() {
    curl -s \
        -u "${ADMIN_USER}:${ADMIN_PASS}" \
        "${NEXUS_URL}/service/rest/v1/repositories" \
    | jq -e ".[] | select(.name == \"$1\")" > /dev/null
}

role_exists() {
    curl -s \
        -u "${ADMIN_USER}:${ADMIN_PASS}" \
        "${NEXUS_URL}/service/rest/v1/security/roles" \
    | jq -e ".[] | select(.id == \"$1\")" > /dev/null
}

ldap_exists() {
    curl -s \
        -u "${ADMIN_USER}:${ADMIN_PASS}" \
        "${NEXUS_URL}/service/rest/v1/security/ldap" \
    | jq -e ".[] | select(.name == \"LDAP\")" > /dev/null
}

# -----------------------------------------------------------------------------
# Generate LDAP configuration
# -----------------------------------------------------------------------------

echo "[INFO] Generating LDAP configuration..."

envsubst '
${LDAP_HOST}
${LDAPS_PORT}
${LDAP_BASE_DN}
${LDAP_BIND_DN}
${LDAP_BIND_PASSWORD}
${LDAP_USER_BASE}
${LDAP_ROLE_BASE}
' < /templates/ldap.json.template > /tmp/ldap.json

# -----------------------------------------------------------------------------
# Blob Store Provisioning
# -----------------------------------------------------------------------------

echo "[INFO] Provisioning blob stores..."

if blobstore_exists "maven-blob"; then
    echo "[SKIP] maven-blob already exists"
else
    api_request \
        POST \
        "/service/rest/v1/blobstores/file" \
        "/templates/blobstore-maven.json"
fi

if blobstore_exists "docker-blob"; then
    echo "[SKIP] docker-blob already exists"
else
    api_request \
        POST \
        "/service/rest/v1/blobstores/file" \
        "/templates/blobstore-docker.json"
fi

if blobstore_exists "pypi-blob"; then
    echo "[SKIP] pypi-blob already exists"
else
    api_request \
        POST \
        "/service/rest/v1/blobstores/file" \
        "/templates/blobstore-pypi.json"
fi

if blobstore_exists "npm-blob"; then
    echo "[SKIP] npm-blob already exists"
else
    api_request \
        POST \
        "/service/rest/v1/blobstores/file" \
        "/templates/blobstore-npm.json"
fi

# -----------------------------------------------------------------------------
# Docker Repository Provisioning
# -----------------------------------------------------------------------------

echo "[INFO] Provisioning Docker repositories..."

if repository_exists "docker-hosted"; then
    echo "[SKIP] docker-hosted already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/docker/hosted" \
        "/templates/docker-hosted.json"
fi

if repository_exists "docker-hub"; then
    echo "[SKIP] docker-hub already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/docker/proxy" \
        "/templates/docker-proxy.json"
fi

if repository_exists "docker-group"; then
    echo "[SKIP] docker-group already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/docker/group" \
        "/templates/docker-group.json"
fi
# -----------------------------------------------------------------------------
# npm Repository Provisioning
# -----------------------------------------------------------------------------

echo "[INFO] Provisioning npm repository..."

if repository_exists "npm-hosted"; then
    echo "[SKIP] npm-hosted already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/npm/hosted" \
        "/templates/npm-hosted.json"
fi

if repository_exists "npm-proxy"; then
    echo "[SKIP] npm-proxy already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/npm/proxy" \
        "/templates/npm-proxy.json"
fi

if repository_exists "npm-group"; then
    echo "[SKIP] npm-group already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/npm/group" \
        "/templates/npm-group.json"
fi

# -----------------------------------------------------------------------------

echo "[INFO] Provisioning PyPI repository..."

if repository_exists "pypi-hosted"; then
    echo "[SKIP] pypi-hosted already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/pypi/hosted" \
        "/templates/pypi-hosted.json"
fi

if repository_exists "pypi-proxy"; then
    echo "[SKIP] pypi-proxy already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/pypi/proxy" \
        "/templates/pypi-proxy.json"
fi

if repository_exists "pypi-group"; then
    echo "[SKIP] pypi-group already exists"
else
    api_request \
        POST \
        "/service/rest/v1/repositories/pypi/group" \
        "/templates/pypi-group.json"
fi

# -----------------------------------------------------------------------------
# Enable Security Realms
# -----------------------------------------------------------------------------

echo "[INFO] Configuring security realms..."

api_request \
    PUT \
    "/service/rest/v1/security/realms/active" \
    "/templates/realm.json"

# -----------------------------------------------------------------------------
# Nexus Role Provisioning
# -----------------------------------------------------------------------------

echo "[INFO] Provisioning Nexus roles..."

if role_exists "developer"; then
    echo "[SKIP] developer role already exists"
else
    api_request \
        POST \
        "/service/rest/v1/security/roles" \
        "/templates/role-developer.json"
fi

if role_exists "admin"; then
    echo "[SKIP] admin role already exists"
else
    api_request \
        POST \
        "/service/rest/v1/security/roles" \
        "/templates/role-admin.json"
fi

# -----------------------------------------------------------------------------
# LDAP Provisioning
# -----------------------------------------------------------------------------

echo "[INFO] Provisioning LDAP..."

if ldap_exists; then
    echo "[SKIP] LDAP already configured"
else
    api_request \
        POST \
        "/service/rest/v1/security/ldap" \
        "/tmp/ldap.json"
fi

# -----------------------------------------------------------------------------
# Provisioning completed
# -----------------------------------------------------------------------------

echo "[SUCCESS] Nexus bootstrap provisioning completed"
