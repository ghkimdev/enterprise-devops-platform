#!/bin/bash
# Spring 배포 노드 init.
# Dockerfile에서 이미 openjdk-17/sshd/deploy 사용자 셋업됨.

set -euo pipefail

echo "[init] Spring 노드 초기화 시작 ($(hostname))"

# 1) Rundeck SSH public key
if [ -f /tmp/deploy-key.pub ]; then
    install -m 600 -o deploy -g deploy \
        /tmp/deploy-key.pub /home/deploy/.ssh/authorized_keys
fi

# 2) 앱 디렉토리
install -d -m 755 -o deploy -g deploy \
    /opt/sample-spring \
    /opt/sample-spring/releases \
    /opt/sample-spring/logs \
    /opt/sample-spring/bin

install -d -m 755 /etc/sample-spring

cat > /opt/sample-spring/bin/start.sh <<'EOF'
#!/bin/bash
set -e

APP_DIR=/opt/sample-spring
CURRENT=${APP_DIR}/current

# pid 파일 정리
if [ -f "${APP_DIR}/app.pid" ]; then
    PID=$(cat "${APP_DIR}/app.pid")

    if kill -0 "$PID" 2>/dev/null; then
        echo "Spring already running (PID=${PID})"
        exit 0
    fi

    rm -f "${APP_DIR}/app.pid"
fi

mkdir -p "${APP_DIR}/logs"

nohup \
  java -jar "${CURRENT}/app.jar" \
  > "${APP_DIR}/logs/app.log" \
  2>&1 &

echo $! > "${APP_DIR}/app.pid"

echo "Started Spring PID=$(cat "${APP_DIR}/app.pid")"
EOF

cat > /opt/sample-spring/bin/stop.sh <<'EOF'
#!/bin/bash

APP_DIR=/opt/sample-spring

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

    # 그래도 안 죽으면 강제 종료
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" || true
    fi
fi

rm -f "${APP_DIR}/app.pid"

echo "Stopped Spring"
EOF

cat > /opt/sample-spring/bin/status.sh <<'EOF'
#!/bin/bash

APP_DIR=/opt/sample-spring

if [ ! -f "${APP_DIR}/app.pid" ]; then
    echo "STOPPED"
    exit 1
fi

PID=$(cat "${APP_DIR}/app.pid")

if kill -0 "$PID" 2>/dev/null; then
    echo "RUNNING"
    exit 0
fi

echo "STOPPED"
exit 1
EOF

chmod +x /opt/sample-spring/bin/*.sh
chown -R deploy:deploy /opt/sample-spring/bin

# 4) 환경 변수 파일
HOST="$(hostname -s)"
case "${HOST}" in
    dev-*)  ENV_NAME=dev ;;
    stg-*)  ENV_NAME=stg ;;
    prod-*) ENV_NAME=prod ;;
    *)      ENV_NAME=unknown ;;
esac
cat > /etc/sample-spring/env << ENV_EOF
SPRING_PROFILES_ACTIVE=${ENV_NAME}
SPRING_DATASOURCE_URL=jdbc:postgresql://db-${ENV_NAME}:5432/payments
SPRING_DATASOURCE_USERNAME=payment_app
SPRING_DATASOURCE_PASSWORD=changeme-${ENV_NAME}
ENV_EOF
chmod 600 /etc/sample-spring/env

echo "[init] 완료"

exec /usr/sbin/sshd -D
