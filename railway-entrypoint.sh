#!/bin/sh
# Railway entrypoint for Invoice Ninja.
#
# Order matters: the account has to exist before nginx opens the public port,
# otherwise the deploy serves an unauthenticated setup wizard to whoever reaches
# the URL first.
set -e

log() { printf '[railway] %s\n' "$*"; }

APP_DIR=/var/www/app
STORAGE="$APP_DIR/storage"
STATE="$STORAGE/railway"
UID_GID=1500:1500

if [ -z "${IN_PASSWORD:-}" ]; then
    log "FATAL: IN_PASSWORD is empty. Set it to a value of your own and redeploy."
    exit 1
fi

if [ -z "${IN_USER_EMAIL:-}" ]; then
    log "FATAL: IN_USER_EMAIL is empty. Set it to your admin email and redeploy."
    exit 1
fi

# Railway mounts volumes owned by uid 0; the image runs as uid 1500.
owner="$(stat -c %u:%g "$STORAGE" 2>/dev/null || echo missing)"
log "storage mount owned by ${owner}, repairing to ${UID_GID}"
mkdir -p "$STATE" "$STORAGE/app/public" "$STORAGE/framework/cache" \
         "$STORAGE/framework/sessions" "$STORAGE/framework/views" "$STORAGE/logs"
chown -R "$UID_GID" "$STORAGE"
chown -R "$UID_GID" "$APP_DIR/bootstrap/cache" 2>/dev/null || true

# Serve anything written to the public disk from the volume too.
if [ ! -e "$APP_DIR/public/storage" ]; then
    ln -s "$STORAGE/app/public" "$APP_DIR/public/storage"
fi

# The encryption key protects stored payment-gateway credentials and signs
# sessions, so it is generated once per deployment onto the volume rather than
# published in the template where every deploy would share one value.
KEY_FILE="$STATE/app_key"
if [ ! -s "$KEY_FILE" ]; then
    printf 'base64:%s\n' "$(openssl rand -base64 32)" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    chown "$UID_GID" "$KEY_FILE"
    log "generated a new APP_KEY on the volume"
else
    log "reusing the APP_KEY stored on the volume"
fi
APP_KEY="$(cat "$KEY_FILE")"
export APP_KEY

if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
    export APP_URL
fi
log "APP_URL=${APP_URL:-unset}"

# Railway injects PORT and its healthcheck dials that port, so nginx has to
# honour it rather than the port baked into a config file.
LISTEN_PORT="${PORT:-8080}"
sed "s/__PORT__/${LISTEN_PORT}/" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
mkdir -p /tmp/nginx-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi
chown -R "$UID_GID" /tmp/nginx-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi
log "nginx will listen on ${LISTEN_PORT}"

# Upstream's own initialisation: restores the storage skeleton, caches config,
# runs migrations, seeds, and creates the first account. It only runs when the
# first argument is supervisord or php-fpm, so it is invoked explicitly here and
# allowed to exit before anything binds a port.
log "running Invoice Ninja initialisation"
su-exec "$UID_GID" /usr/local/bin/docker-entrypoint php-fpm --version > /dev/null

cd "$APP_DIR"
if ! su-exec "$UID_GID" php artisan tinker /railway-seed.php; then
    log "WARNING: admin credential step failed; see the output above"
fi

log "starting php-fpm, nginx, the scheduler and 2 queue workers"
exec supervisord -c /etc/supervisord.railway.conf
