FROM jenkins/jenkins:2.564

USER root

# 1. Docker 설치
RUN apt-get update && apt-get install -y docker.io 

# 2. Jenkins 플러그인 설치
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# 3. Jenkins Bootstrap 
COPY casc/ /var/jenkins_home/casc_configs/
COPY seed/ /var/jenkins_home/seed/

RUN chown -R jenkins:jenkins \
    /var/jenkins_home/casc_configs \
    /var/jenkins_home/seed

ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs

# 4. 권한 복구
USER jenkins
