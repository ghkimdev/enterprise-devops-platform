FROM jenkins/jenkins:2.564

USER root

# 1. CA 복사
COPY certs/ca.crt /usr/local/share/ca-certificates/self-ca.crt

# 2. OS trust store 업데이트
RUN apt-get update && apt-get install -y ca-certificates \
    && update-ca-certificates

# 3. Java truststore에 CA 등록
RUN keytool -importcert -noprompt \
  -alias self-ca \
  -file /usr/local/share/ca-certificates/self-ca.crt \
  -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit

# 4. 권한 복구
USER jenkins
