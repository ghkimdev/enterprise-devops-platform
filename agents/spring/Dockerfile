FROM jenkins/inbound-agent:latest

USER root

RUN apt-get update && \
    apt-get install -y \
        git \
        subversion \
        curl \
        unzip  \
        openjdk-21-jdk \
        maven

USER jenkins
