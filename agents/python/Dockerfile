FROM jenkins/inbound-agent:latest

USER root

RUN apt-get update && \
    apt-get install -y \
        git \
        subversion \
        curl \
        unzip \
        python3 \
        python3-pip \
        phthon3-venv

USER jenkins
