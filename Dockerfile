FROM alpinelinux/unbound:latest

# Metadata
LABEL org.opencontainers.image.title="Unbound DNS Server" \
    org.opencontainers.image.description="🚀 Flexible Unbound DNS server with DoT, DNSSEC support. Auto-published Docker images with comprehensive testing." \
    org.opencontainers.image.url="https://github.com/zyrakq/docker-unbound" \
    org.opencontainers.image.source="https://github.com/zyrakq/docker-unbound" \
    org.opencontainers.image.documentation="https://github.com/zyrakq/docker-unbound#readme" \
    org.opencontainers.image.author="Zyrakq <serg.shehov@tutanota.com>" \
    org.opencontainers.image.licenses="Apache-2.0 OR MIT" \
    org.opencontainers.image.vendor="Zyrakq"

# Добавляем envsubst для подстановки переменных и ca-certificates для SSL/TLS
RUN apk add --no-cache gettext ca-certificates openssl && update-ca-certificates

# Копируем шаблон конфига
COPY unbound.conf.template /opt/unbound/etc/unbound/unbound.conf.template

# Скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]