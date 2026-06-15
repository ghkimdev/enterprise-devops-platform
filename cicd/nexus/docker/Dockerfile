FROM sonatype/nexus3:3.92.0

USER root

# 1. 프로비저닝 스크립트 추가
COPY scripts /opt/nexus/scripts

RUN chmod +x /opt/nexus/scripts/*.sh

# 2. 권한 복구
USER nexus
