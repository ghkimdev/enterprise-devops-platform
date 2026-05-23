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
        && rm -rf /var/lib/apt/lists/*

#
# Node.js 20 LTS
#
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

#
# Pin npm version
#
RUN npm install -g npm@10

#
# Verify toolchain
#
RUN node -v && npm -v

USER jenkins
