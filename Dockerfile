FROM alpinelinux/unbound:latest

# Добавляем envsubst для подстановки переменных и ca-certificates для SSL/TLS
RUN apk add --no-cache gettext ca-certificates openssl && update-ca-certificates

# Копируем шаблон конфига
COPY unbound.conf.template /opt/unbound/etc/unbound/unbound.conf.template

# Скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]