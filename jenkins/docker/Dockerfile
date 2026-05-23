FROM jenkins/jenkins:2.564

USER root

# 1. CA 복사
COPY certs/ca.crt /usr/local/share/ca-certificates/self-ca.crt

# 2. OS trust store 업데이트
RUN apt-get update && apt-get install -y ca-certificates \
    docker.io \
    && update-ca-certificates

# 3. Java truststore에 CA 등록
RUN keytool -importcert -noprompt \
  -alias self-ca \
  -file /usr/local/share/ca-certificates/self-ca.crt \
  -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit

# 4. Jenkins 플러그인 설치
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# 6. Jenkins Bootstrap 
COPY casc/ /var/jenkins_home/casc_configs/
COPY seed/ /var/jenkins_home/seed/

RUN chown -R jenkins:jenkins \
    /var/jenkins_home/casc_configs \
    /var/jenkins_home/seed

ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs

# 5. 권한 복구
USER jenkins
