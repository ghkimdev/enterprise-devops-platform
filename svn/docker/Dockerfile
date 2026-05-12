FROM debian:bookworm-20260505-slim

COPY certs/ca.crt /usr/local/share/ca-certificates/self-ca.crt

RUN apt-get update && apt-get install -y \
    gettext-base \
    apache2 \
    subversion \
    libapache2-mod-svn \
    ldap-utils \
    ca-certificates \
    && update-ca-certificates

RUN a2enmod dav dav_svn ldap authnz_ldap

# 설정 파일 복사
COPY conf/svn.conf.template /etc/apache2/conf-enabled/svn.conf.template
COPY conf/svn-authz.conf /etc/apache2/svn-authz.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /var/svn/repos

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
