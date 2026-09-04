# Invoice Ninja for Railway.
#
# Wraps the official Invoice Ninja image. Everything a deployer would otherwise
# have to type is baked in here, because Railway drops a literal defaultValue at
# template-generate time and publishes the variable as a blank required field.
FROM invoiceninja/invoiceninja:5.13.37

USER root

RUN apk add --no-cache nginx su-exec openssl

# Application settings that have exactly one sane value on Railway.
ENV FILESYSTEM_DISK=debian_docker \
    CACHE_DRIVER=file \
    SESSION_DRIVER=file \
    QUEUE_CONNECTION=database \
    PDF_GENERATOR=snappdf \
    TRUSTED_PROXIES=* \
    LOG_CHANNEL=stderr \
    APP_ENV=production \
    APP_DEBUG=false \
    SELF_HOSTED=true \
    REQUIRE_HTTPS=false \
    IN_USER_EMAIL=admin@example.com

COPY nginx.conf /etc/nginx/nginx.conf.template
COPY php-fpm-railway.conf /usr/local/etc/php-fpm.d/zzz-railway.conf
COPY supervisord.conf /etc/supervisord.railway.conf
COPY railway-seed.php /railway-seed.php
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["supervisord"]
