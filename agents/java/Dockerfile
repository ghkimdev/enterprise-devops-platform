FROM jenkins/inbound-agent:3355.v388858a_47b_33-20

USER root

RUN apt-get update && \
    apt-get install -y \
        docker.io \
        git \
        subversion \
        curl \
        unzip  \
        openjdk-21-jdk \
        maven \
        && rm -rf /var/lib/apt/lists/*

USER jenkins
