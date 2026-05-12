#!/bin/bash
set -e

envsubst < /etc/apache2/conf-enabled/svn.conf.template \
  > /etc/apache2/conf-enabled/svn.conf

chown -R www-data:www-data /var/svn/repos

exec apachectl -D FOREGROUND
