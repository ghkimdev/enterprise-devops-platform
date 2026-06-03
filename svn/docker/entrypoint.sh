#!/bin/bash
set -e

echo "[entrypoint] generating apache config..."
envsubst < /etc/apache2/conf-enabled/svn.conf.template \
  > /etc/apache2/conf-enabled/svn.conf

echo "[entrypoint] initializing svn repositories..."
./init-svn.sh

echo "[entrypoint] starting apache..."
exec apachectl -D FOREGROUND
