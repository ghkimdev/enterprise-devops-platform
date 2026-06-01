#!/bin/bash
# React 배포 노드 (nginx + 정적 파일 서빙) init.
#
# Rundeck이 ssh로 들어와서 /var/lib/rundeck/project-scripts/sample/deploy-react.sh
# 를 실행할 수 있도록 준비한다.

set -euo pipefail

echo "[init] React 노드 초기화 시작 ($(hostname))"

# 1) 필수 패키지
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -qq -y \
    nginx \
    curl \
    openssh-server \
    sudo \
    ca-certificates

# 2) deploy 사용자 + sudo NOPASSWD
if ! id deploy >/dev/null 2>&1; then
    useradd -m -s /bin/bash deploy
fi
echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy
chmod 0440 /etc/sudoers.d/deploy

# 3) Rundeck SSH public key 등록
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
if [ -f /tmp/deploy-key.pub ]; then
    install -m 600 -o deploy -g deploy /tmp/deploy-key.pub /home/deploy/.ssh/authorized_keys
    echo "[init] SSH authorized_keys 등록 완료"
else
    echo "[init] WARNING: /tmp/deploy-key.pub 가 없음 — ssh 접속 불가"
fi

# 4) 디렉토리 구조 + 권한
install -d -m 755 -o deploy -g deploy \
    /var/www/sample-react \
    /var/www/sample-react/releases \
    /var/www/sample-react/bin \
    /var/www/html
install -d -m 755 /etc/sample-react

cat > /var/www/sample-react/bin/start.sh <<'EOF'
#!/bin/bash
nginx
EOF

cat > /var/www/sample-react/bin/stop.sh <<'EOF'
#!/bin/bash
nginx -s stop || true
EOF

cat > /var/www/sample-react/bin/status.sh <<'EOF'
#!/bin/bash
pgrep nginx >/dev/null
EOF

chmod +x /var/www/sample-react/bin/*.sh
chown -R deploy:deploy /var/www/sample-react/bin

# 5) 환경별 runtime-config.js 사전 배치 (deploy script가 복사)
# 호스트네임으로 env 추론 (dev-web-01 → dev, stg-web-01 → stg, prod-web-01 → prod)
HOST="$(hostname -s)"
case "${HOST}" in
    dev-*)  ENV_NAME=dev ;;
    stg-*)  ENV_NAME=stg ;;
    prod-*) ENV_NAME=prod ;;
    *)      ENV_NAME=unknown ;;
esac

cat > "/etc/sample-react/runtime-config-${ENV_NAME}.js" <<EOF
window.RUNTIME_CONFIG = {
    API_BASE_URL: "https://api-${ENV_NAME}.example.com",
    ENV: "${ENV_NAME}",
    HOST: "${HOST}"
};
EOF

# 6) nginx 사이트 설정
cat > /etc/nginx/sites-available/sample-react <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html/sample-react;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
EOF
ln -sf /etc/nginx/sites-available/sample-react /etc/nginx/sites-enabled/default

# 7) sshd 호스트키 생성 (한 번만)
ssh-keygen -A
install -d -m 0755 /run/sshd

nginx

# 9) 완료 flag
echo "[init] React 노드 초기화 완료"

# 10) hand-off to systemd (PID 1로)
exec /usr/sbin/sshd -D

