#!/bin/bash
# FastAPI 배포 노드 init.
# Dockerfile에서 이미 python3/sshd/deploy 사용자 셋업됨.

set -euo pipefail

echo "[init] FastAPI 노드 초기화 시작 ($(hostname))"

# 1) Rundeck SSH public key
if [ -f /tmp/deploy-key.pub ]; then
    install -m 600 -o deploy -g deploy \
        /tmp/deploy-key.pub /home/deploy/.ssh/authorized_keys
fi

# 2) 앱 디렉토리
install -d -m 755 -o deploy -g deploy \
    /opt/sample-fastapi \
    /opt/sample-fastapi/releases \
    /opt/sample-fastapi/logs \
    /opt/sample-fastapi/bin

install -d -m 755 /etc/sample-fastapi

cat > /opt/sample-fastapi/bin/start.sh <<'EOF'
#!/bin/bash
set -e

APP_DIR=/opt/sample-fastapi
CURRENT=${APP_DIR}/current

if [ -f "${APP_DIR}/app.pid" ]; then
    PID=$(cat "${APP_DIR}/app.pid")

    if kill -0 "$PID" 2>/dev/null; then
        echo "already running"
        exit 0
    fi

    rm -f "${APP_DIR}/app.pid"
fi

mkdir -p ${APP_DIR}/logs

cd "${CURRENT}"

nohup \
  "${CURRENT}/.venv/bin/uvicorn" \
  app.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  > ${APP_DIR}/logs/app.log \
  2>&1 &

echo $! > ${APP_DIR}/app.pid
EOF

cat > /opt/sample-fastapi/bin/stop.sh <<'EOF'
#!/bin/bash

APP_DIR=/opt/sample-fastapi

if [ ! -f "${APP_DIR}/app.pid" ]; then
    exit 0
fi

PID=$(cat "${APP_DIR}/app.pid")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"

    for i in $(seq 1 10); do
        if ! kill -0 "$PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done
fi

rm -f "${APP_DIR}/app.pid"
EOF

cat > /opt/sample-fastapi/bin/status.sh <<'EOF'
#!/bin/bash

APP_DIR=/opt/sample-fastapi

if [ ! -f "${APP_DIR}/app.pid" ]; then
    exit 1
fi

PID=$(cat "${APP_DIR}/app.pid")

kill -0 "$PID" 2>/dev/null
EOF

chmod +x /opt/sample-fastapi/bin/*.sh
chown -R deploy:deploy /opt/sample-fastapi/bin

# 4) 환경 변수 파일
HOST="$(hostname -s)"
case "${HOST}" in
    dev-*)  ENV_NAME=dev ;;
    stg-*)  ENV_NAME=stg ;;
    prod-*) ENV_NAME=prod ;;
    *)      ENV_NAME=unknown ;;
esac
cat > /etc/sample-fastapi/env << ENV_EOF
APP_ENV=${ENV_NAME}
DATABASE_URL=postgresql://ml_app:changeme@db-${ENV_NAME}:5432/ml
MODEL_PATH=/opt/sample-fastapi/current/app/models
ENV_EOF
chmod 600 /etc/sample-fastapi/env

echo "[init] 완료"

exec /usr/sbin/sshd -D
