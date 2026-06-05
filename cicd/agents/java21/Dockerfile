FROM jenkins/inbound-agent:3355.v388858a_47b_33-20

USER root

RUN apt-get update && \
    apt-get install -y \
        docker.io \
        git \
        subversion \
        curl \
        unzip \
        ca-certificates \
        openjdk-21-jdk \
        maven \
        jq \
        zip \
        rsync \
    && rm -rf /var/lib/apt/lists/*

#
# Maven local repo
#
RUN mkdir -p \
      /workspace \
      /home/jenkins/.m2 \
    && chown -R jenkins:jenkins \
      /workspace \
      /home/jenkins/.m2

#
# Verify
#
RUN java -version && \
    mvn -version

USER jenkins

WORKDIR /workspace
