FROM debian:bookworm-20260505-slim

COPY certs/ca.crt /usr/local/share/ca-certificates/self-ca.crt

RUN apt-get update && apt-get install -y \
    apache2 \
    subversion \
    libapache2-mod-svn \
    ldap-utils \
    ca-certificates \
    && update-ca-certificates

RUN a2enmod dav dav_svn ldap authnz_ldap

# 설정 파일 복사
COPY svn.conf /etc/apache2/conf-available/svn.conf
COPY svn-authz.conf /etc/apache2/svn-authz.conf

# 설정 활성화
RUN a2enconf svn

RUN mkdir -p /var/svn/repos

EXPOSE 80

CMD ["bash", "-c", "chown -R www-data:www-data /var/svn/repos && apachectl -D FOREGROUND"]
