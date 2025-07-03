#!/bin/sh

# Configure TLS ports separately for server and upstream
TLS_SERVER_PORT="${TLS_SERVER_PORT:-853}"
TLS_UPSTREAM_PORT="${TLS_UPSTREAM_PORT:-853}"
export TLS_SERVER_PORT
export TLS_UPSTREAM_PORT

# Configure logging
if [ "${ENABLE_LOGGING:-false}" = "true" ]; then
    export LOGGING_CONFIG="verbosity: ${LOG_LEVEL:-1}
    use-syslog: no
    logfile: \"\"
    log-queries: ${LOG_QUERIES:-no}
    log-replies: ${LOG_REPLIES:-no}"
else
    export LOGGING_CONFIG="verbosity: 0"
fi

# Configure caching
if [ "${ENABLE_CACHE:-true}" = "true" ]; then
    export CACHE_CONFIG="do-not-query-localhost: no
    prefetch: ${PREFETCH:-yes}
    prefetch-key: ${PREFETCH_KEY:-yes}"
else
    export CACHE_CONFIG="cache-max-ttl: 0
    cache-min-ttl: 0"
fi

# Configure DNSSEC
if [ "${ENABLE_DNSSEC:-true}" = "true" ]; then
    export DNSSEC_CONFIG="trust-anchor-file: \"/usr/share/dnssec-root/trusted-key.key\"
    val-permissive-mode: no
    val-clean-additional: yes"
else
    export DNSSEC_CONFIG="# DNSSEC disabled"
fi

# Configure Access Control
if [ -n "$ACCESS_CONTROL_CUSTOM" ]; then
    # Parse string like "192.168.1.0/24 allow,10.0.0.0/8 deny"
    ACCESS_CONTROL_CONFIG=""
    # Use POSIX-compatible approach
    OLD_IFS="$IFS"
    IFS=','
    set -- $ACCESS_CONTROL_CUSTOM
    IFS="$OLD_IFS"
    
    for rule in "$@"; do
        ACCESS_CONTROL_CONFIG="${ACCESS_CONTROL_CONFIG}    access-control: ${rule}
"
    done
    export ACCESS_CONTROL="$ACCESS_CONTROL_CONFIG"
else
    export ACCESS_CONTROL="    access-control: 0.0.0.0/0 allow"
fi

# Configure Private Addresses (block private addresses in responses)
if [ "${BLOCK_PRIVATE:-true}" = "false" ]; then
    export PRIVATE_ADDRESSES_CONFIG="# Private address blocking disabled"
else
    export PRIVATE_ADDRESSES_CONFIG="private-address: ${PRIVATE_ADDRESS:-192.168.0.0/16}
    private-address: ${PRIVATE_ADDRESS2:-172.16.0.0/12}
    private-address: ${PRIVATE_ADDRESS3:-10.0.0.0/8}"
fi

# Configure local domains (like dnsmasq address=/domain/ip)
LOCAL_DOMAINS_CONFIG=""
if [ -n "$LOCAL_DOMAINS" ]; then
    # Use POSIX-compatible approach
    OLD_IFS="$IFS"
    IFS=','
    set -- $LOCAL_DOMAINS
    IFS="$OLD_IFS"
    
    for domain_config in "$@"; do
        # Parse domain_config manually
        domain_name=$(echo "$domain_config" | cut -d':' -f1)
        domain_ip=$(echo "$domain_config" | cut -d':' -f2)
        domain_port=$(echo "$domain_config" | cut -d':' -f3)
        
        # Check if domain_port is empty or is an IP (for local-data mode)
        if [ -z "$domain_port" ] || echo "$domain_ip" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            # This is local-data mode (like dnsmasq address=/domain/ip)
            LOCAL_DOMAINS_CONFIG="${LOCAL_DOMAINS_CONFIG}    local-zone: \"${domain_name}.\" redirect
    local-data: \"${domain_name}. IN A ${domain_ip}\"
"
        else
            # This is stub-zone mode (traditional DNS forwarding)
            # Set default port if not specified
            if [ -z "$domain_port" ]; then
                domain_port="53"
            fi
            
            LOCAL_DOMAINS_CONFIG="${LOCAL_DOMAINS_CONFIG}    local-zone: \"${domain_name}.\" transparent

stub-zone:
    name: \"${domain_name}.\"
    stub-addr: ${domain_ip}@${domain_port}
    stub-prime: no
"
        fi
    done
fi
export LOCAL_DOMAINS_CONFIG

# Configure DoT server interface (port 853)
if [ "${ENABLE_DOT_SERVER:-false}" = "true" ]; then
    # Add interface for DoT server
    export DOT_INTERFACE="interface: ${INTERFACE:-0.0.0.0}@${TLS_SERVER_PORT}"
    
    # Configure TLS certificates
    CERT_DIR="/etc/unbound/tls"
    TLS_KEY_PATH="${TLS_SERVICE_KEY:-$CERT_DIR/server.key}"
    TLS_CERT_PATH="${TLS_SERVICE_PEM:-$CERT_DIR/server.pem}"
    
    # Check if external certificates are provided
    if [ -n "$TLS_SERVICE_KEY" ] && [ -n "$TLS_SERVICE_PEM" ]; then
        echo "Using external TLS certificates:"
        echo "  Key: $TLS_SERVICE_KEY"
        echo "  Certificate: $TLS_SERVICE_PEM"
        
        # Verify external certificates exist
        if [ ! -f "$TLS_SERVICE_KEY" ] || [ ! -f "$TLS_SERVICE_PEM" ]; then
            echo "ERROR: External TLS certificates not found!"
            echo "  Key file: $TLS_SERVICE_KEY"
            echo "  Cert file: $TLS_SERVICE_PEM"
            exit 1
        fi
    else
        # Generate self-signed certificate if not provided
        mkdir -p "$CERT_DIR"
        
        if [ ! -f "$TLS_CERT_PATH" ] || [ ! -f "$TLS_KEY_PATH" ]; then
            echo "Generating self-signed certificate for DoT server..."
            openssl req -x509 -newkey rsa:2048 -keyout "$TLS_KEY_PATH" -out "$TLS_CERT_PATH" \
                -days 365 -nodes -subj "/C=US/ST=Local/L=Local/O=Unbound/CN=${TLS_CERT_DOMAIN:-localhost}" \
                -addext "subjectAltName=DNS:${TLS_CERT_DOMAIN:-localhost},DNS:*.local,IP:127.0.0.1,IP:0.0.0.0"
            chmod 600 "$TLS_KEY_PATH"
            chmod 644 "$TLS_CERT_PATH"
        fi
    fi
    
    export TLS_SERVER_CONFIG="tls-service-key: \"$TLS_KEY_PATH\"
    tls-service-pem: \"$TLS_CERT_PATH\"
    tls-port: ${TLS_SERVER_PORT}"
else
    export TLS_SERVER_CONFIG="# DoT server disabled"
    export DOT_INTERFACE="# DoT interface disabled"
fi

# Configure forward zone
if [ "${ENABLE_DOT:-true}" = "true" ]; then
    FORWARD_ZONE_CONFIG="forward-zone:
    name: \".\"
    forward-tls-upstream: yes"
    # Add SSL certificate bundle configuration
    export TLS_CONFIG="tls-cert-bundle: \"/etc/ssl/certs/ca-certificates.crt\""
else
    FORWARD_ZONE_CONFIG="forward-zone:
    name: \".\""
    export TLS_CONFIG="# TLS disabled"
fi

# Build upstream servers list
UPSTREAM_LIST=""

# First, collect servers from UPSTREAM_DNS_1 to UPSTREAM_DNS_8
for i in $(seq 1 8); do
    eval "server=\$UPSTREAM_DNS_$i"
    if [ -n "$server" ]; then
        UPSTREAM_LIST="$UPSTREAM_LIST $server"
    fi
done

# If UPSTREAM_SERVERS is provided, use it instead
if [ -n "$UPSTREAM_SERVERS" ]; then
    UPSTREAM_LIST="$UPSTREAM_SERVERS"
fi

# If no servers are configured, use default values based on DoT mode
if [ -z "$UPSTREAM_LIST" ]; then
    if [ "${ENABLE_DOT:-true}" = "true" ]; then
        UPSTREAM_LIST="1.1.1.1@${TLS_UPSTREAM_PORT}#cloudflare-dns.com 1.0.0.1@${TLS_UPSTREAM_PORT}#cloudflare-dns.com 8.8.8.8@${TLS_UPSTREAM_PORT}#dns.google 8.8.4.4@${TLS_UPSTREAM_PORT}#dns.google"
    else
        UPSTREAM_LIST="1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4"
    fi
fi

# Function to parse server configuration
parse_server_config() {
    local server_config="$1"
    local server_ip=""
    local server_port=""
    local server_domain=""
    
    # Check if server contains @ (port specification)
    if echo "$server_config" | grep -q "@"; then
        # Split by @
        server_ip=$(echo "$server_config" | cut -d'@' -f1)
        port_and_domain=$(echo "$server_config" | cut -d'@' -f2)
        
        # Check if port_and_domain contains # (domain specification)
        if echo "$port_and_domain" | grep -q "#"; then
            server_port=$(echo "$port_and_domain" | cut -d'#' -f1)
            server_domain=$(echo "$port_and_domain" | cut -d'#' -f2)
        else
            server_port="$port_and_domain"
            server_domain=""
        fi
    else
        # No @ found, check if it contains # (domain only)
        if echo "$server_config" | grep -q "#"; then
            server_ip=$(echo "$server_config" | cut -d'#' -f1)
            server_domain=$(echo "$server_config" | cut -d'#' -f2)
            server_port=""
        else
            # Plain IP or domain
            server_ip="$server_config"
            server_port=""
            server_domain=""
        fi
    fi
    
    echo "$server_ip|$server_port|$server_domain"
}

# Add upstream servers
for server in $UPSTREAM_LIST; do
    # Parse server configuration
    parsed=$(parse_server_config "$server")
    server_ip=$(echo "$parsed" | cut -d'|' -f1)
    server_port=$(echo "$parsed" | cut -d'|' -f2)
    server_domain=$(echo "$parsed" | cut -d'|' -f3)
    
    if [ "${ENABLE_DOT:-true}" = "true" ]; then
        # DoT upstream configuration
        if [ -n "$server_port" ]; then
            # Custom port specified
            dot_port="$server_port"
        else
            # Use default DoT port
            dot_port="${TLS_UPSTREAM_PORT}"
        fi
        
        if [ -n "$server_domain" ]; then
            # Domain specified
            FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}#${server_domain}"
        else
            # No domain, try to auto-detect for known servers
            case $server_ip in
                1.1.1.1|1.0.0.1)
                    FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}#cloudflare-dns.com"
                    ;;
                8.8.8.8|8.8.4.4)
                    FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}#dns.google"
                    ;;
                9.9.9.9|149.112.112.112)
                    FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}#quad9.net"
                    ;;
                208.67.222.222|208.67.220.220)
                    FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}#opendns.com"
                    ;;
                *)
                    # Unknown server, use without domain (may not work for DoT)
                    FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dot_port}"
                    ;;
            esac
        fi
    else
        # Plain DNS upstream - ignore DoT ports and domains
        if [ -n "$server_port" ] && [ "$server_port" != "${TLS_UPSTREAM_PORT}" ]; then
            # Use custom port only if it's not the default DoT port
            dns_port="$server_port"
        else
            # Use default DNS port (53) - ignore DoT port ${TLS_UPSTREAM_PORT}
            dns_port="53"
        fi
        
        FORWARD_ZONE_CONFIG="${FORWARD_ZONE_CONFIG}
    forward-addr: ${server_ip}@${dns_port}"
    fi
done

export FORWARD_ZONE_CONFIG

# Export all variables with default values for envsubst
export INTERFACE="${INTERFACE:-0.0.0.0}"
export PORT="${PORT:-53}"
# ACCESS_CONTROL is already set above, don't override it
export NUM_THREADS="${NUM_THREADS:-1}"
export MSG_BUFFER_SIZE="${MSG_BUFFER_SIZE:-65552}"
export MSG_CACHE_SIZE="${MSG_CACHE_SIZE:-4m}"
export RRSET_CACHE_SIZE="${RRSET_CACHE_SIZE:-4m}"
export CACHE_TTL="${CACHE_TTL:-86400}"
export HIDE_IDENTITY="${HIDE_IDENTITY:-yes}"
export HIDE_VERSION="${HIDE_VERSION:-yes}"
# PRIVATE_ADDRESS variables are set above based on BLOCK_PRIVATE setting

# Output config for debugging if logging is enabled
if [ "${ENABLE_LOGGING:-false}" = "true" ]; then
    echo "=== Generated Unbound Configuration ==="
fi

# Generate final config
envsubst < /opt/unbound/etc/unbound/unbound.conf.template > /etc/unbound/unbound.conf

# Show generated config if logging is enabled
if [ "${ENABLE_LOGGING:-false}" = "true" ]; then
    cat /etc/unbound/unbound.conf
    echo "======================================="
fi

# Start unbound
exec unbound -d