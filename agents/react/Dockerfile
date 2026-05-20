FROM jenkins/inbound-agent:latest

USER root

RUN apt-get update && \
    apt-get install -y \
        git \
        subversion \
        curl \
        unzip 

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

USER jenkins

