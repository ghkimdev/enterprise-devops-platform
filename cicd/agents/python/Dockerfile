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
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

#
# Tooling virtualenv
#
RUN python3 -m venv /opt/pytools && \
    /opt/pytools/bin/pip install --upgrade pip setuptools wheel && \
    /opt/pytools/bin/pip install \
        pytest \
        pip-audit

#
# PATH
#
ENV PATH="/opt/pytools/bin:${PATH}"

#
# Workspace
#
RUN mkdir -p \
      /workspace \
      /home/jenkins/.pip \
    && chown -R jenkins:jenkins \
      /workspace \
      /home/jenkins

USER jenkins

WORKDIR /workspace
