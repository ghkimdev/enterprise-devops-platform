FROM sonatype/nexus3:3.92.0

USER root

# 1. CA 복사
COPY certs/ca.crt /usr/local/share/ca-certificates/self-ca.crt

# 2. OS trust store 업데이트
RUN apk add --no-cache ca-certificates \
    && update-ca-certificates

# 3. Java truststore에 CA 등록
RUN keytool -importcert -noprompt \
  -alias self-ca \
  -file /usr/local/share/ca-certificates/self-ca.crt \
  -keystore /usr/lib/jvm/java-25-openjdk/lib/security/cacerts \
  -storepass changeit

# 4. 프로비저닝 스크립트 추가
COPY scripts /opt/nexus/scripts

RUN chmod +x /opt/nexus/scripts/*.sh

# 5. 권한 복구
USER nexus
