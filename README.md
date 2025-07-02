# 🚀 Unbound DNS Server Docker Container

A flexible and configurable Unbound DNS server container with support for DNS-over-TLS (DoT), DNSSEC, and custom upstream configurations.

## ✨ Features

- 🔒 **DNS-over-TLS (DoT)**: Secure DNS queries using TLS encryption
- 🛡️ **DNSSEC Validation**: Built-in DNSSEC support for enhanced security
- 🌐 **Flexible Upstream Configuration**: Easy configuration of upstream DNS servers
- 🏠 **Local Domains**: Support for local domain resolution (like dnsmasq address=/domain/ip)
- ⚡ **Performance Tuning**: Configurable caching and threading options
- 🔐 **Security Features**: Private address blocking, identity hiding
- 📊 **Comprehensive Logging**: Detailed logging options for debugging

## 🚀 Quick Start

### 🏠 Basic Usage

```bash
docker run -d \
  --name unbound \
  -p 53:53/udp \
  -p 53:53/tcp \
  your-registry/unbound:latest
```

### ⚙️ With Custom Configuration

```bash
docker run -d \
  --name unbound \
  -p 53:53/udp \
  -p 53:53/tcp \
  -e UPSTREAM_SERVERS="1.1.1.1 8.8.8.8" \
  -e ENABLE_DOT=true \
  -e ENABLE_DNSSEC=true \
  your-registry/unbound:latest
```

## ⚙️ Configuration

### 🌐 Network Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `INTERFACE` | `0.0.0.0` | Interface to bind to (use `0.0.0.0` for all interfaces) |
| `PORT` | `53` | DNS port to listen on |
| `ACCESS_CONTROL` | `0.0.0.0/0 allow` | Basic access control rule |
| `ACCESS_CONTROL_CUSTOM` | - | Custom access control rules (comma-separated) |

#### 🔐 Access Control Configuration

**ACCESS_CONTROL** is the basic rule that applies to all clients. The default `0.0.0.0/0 allow` allows access from any IP address, which is **unsafe for production**.

**ACCESS_CONTROL_CUSTOM** allows you to define detailed access rules in the format: `network action,network action`

**Common scenarios:**

**Localhost only (testing):**

```bash
ACCESS_CONTROL_CUSTOM="127.0.0.0/8 allow,::1/128 allow,0.0.0.0/0 deny"
```

**Home network:**

```bash
ACCESS_CONTROL_CUSTOM="192.168.0.0/16 allow,127.0.0.0/8 allow,0.0.0.0/0 deny"
```

**Corporate network:**

```bash
ACCESS_CONTROL_CUSTOM="10.0.0.0/8 allow,192.168.0.0/16 allow,172.16.0.0/12 allow,0.0.0.0/0 deny"
```

**Docker environment (containers + localhost):**

```bash
ACCESS_CONTROL_CUSTOM="127.0.0.0/8 allow,172.16.0.0/12 allow,0.0.0.0/0 deny"
```

**Specific networks with exceptions:**

```bash
ACCESS_CONTROL_CUSTOM="192.168.1.0/24 allow,192.168.100.0/24 deny,192.168.0.0/16 allow,0.0.0.0/0 deny"
```

**How to determine Docker networks:**

```bash
# List Docker networks
docker network ls

# Inspect specific network
docker network inspect bridge

# Check container IP
docker inspect <container_name> | grep IPAddress
```

### 🌐 Upstream DNS Servers

You can configure upstream DNS servers using an extended format that supports custom DoT domains and ports.

#### 🔧 Extended Format Syntax

The format is: `IP@PORT#DOMAIN` where:

- `IP` - Server IP address or hostname (required)
- `@PORT` - Custom port (optional, defaults to 53 for plain DNS, 853 for DoT)
- `#DOMAIN` - Domain name for DoT certificate validation (optional)

**Examples:**

```bash
1.1.1.1                           # Plain DNS on port 53
1.1.1.1@853                       # DoT on port 853 (auto-detect domain)
1.1.1.1@853#cloudflare-dns.com    # DoT with custom domain
your-dns.example.com@853#your-dns.example.com  # Custom DoT server
your-dns.example.com@8853#your-dns.example.com # Custom DoT server on custom port
```

#### 1️⃣ Method 1: Individual Server Variables (Recommended)

```bash
UPSTREAM_DNS_1=1.1.1.1@853#cloudflare-dns.com
UPSTREAM_DNS_2=1.0.0.1@853#cloudflare-dns.com
UPSTREAM_DNS_3=8.8.8.8@853#dns.google
UPSTREAM_DNS_4=8.8.4.4@853#dns.google
UPSTREAM_DNS_5=your-dns.example.com@853#your-dns.example.com
UPSTREAM_DNS_6=another-dns.com@8853#another-dns.com
UPSTREAM_DNS_7=9.9.9.9@853#quad9.net
UPSTREAM_DNS_8=149.112.112.112@853#quad9.net
```

#### 2️⃣ Method 2: Space-Separated List

```bash
UPSTREAM_SERVERS="1.1.1.1@853#cloudflare-dns.com 8.8.8.8@853#dns.google your-dns.example.com@853#your-dns.example.com"
```

#### 🤖 Auto-Detection for Known Servers

For well-known DNS providers, domains are auto-detected if not specified:

- `1.1.1.1`, `1.0.0.1` → `cloudflare-dns.com`
- `8.8.8.8`, `8.8.4.4` → `dns.google`
- `9.9.9.9`, `149.112.112.112` → `quad9.net`
- `208.67.222.222`, `208.67.220.220` → `opendns.com`

So you can use:

```bash
UPSTREAM_DNS_1=1.1.1.1@853  # Automatically becomes 1.1.1.1@853#cloudflare-dns.com
UPSTREAM_DNS_2=8.8.8.8@853  # Automatically becomes 8.8.8.8@853#dns.google
```

### 🏠 Local Domains

Configure local domain resolution (similar to dnsmasq `address=/domain/ip`):

```bash
LOCAL_DOMAINS=local:192.168.31.56,dev:192.168.31.57
```

Format: `domain_name:ip_address` - all queries to `*.domain_name` will return the specified IP address.

For traditional DNS forwarding to another DNS server, use: `domain_name:server_ip:port`

### ⚡ Core Features

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_DOT` | `true` | Enable DNS-over-TLS for upstream queries |
| `ENABLE_DOT_SERVER` | `false` | Enable DoT server on port 853 |
| `ENABLE_DNSSEC` | `true` | Enable DNSSEC validation |
| `ENABLE_CACHE` | `true` | Enable DNS caching |
| `ENABLE_LOGGING` | `false` | Enable detailed logging |

### 🔒 DNS-over-TLS Server Configuration

The container can act as a DoT server, providing secure DNS resolution over TLS on port 853. This is useful for systemd-resolved and other DoT-capable clients.

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_DOT_SERVER` | `false` | Enable DoT server functionality |
| `TLS_SERVICE_KEY` | - | Path to external TLS private key file |
| `TLS_SERVICE_PEM` | - | Path to external TLS certificate file |
| `TLS_CERT_DOMAIN` | `localhost` | Domain name for auto-generated certificate |
| `TLS_PORT` | `853` | DoT server port |

#### 🚀 Quick DoT Server Setup

```yaml
services:
  unbound:
    build: .
    ports:
      - "53:53/udp"
      - "853:853/tcp"  # DoT server port
    environment:
      - ENABLE_DOT_SERVER=true
      - ENABLE_DOT=true
      - ENABLE_DNSSEC=true
    restart: unless-stopped
```

#### 🔐 SSL Certificate Management

The DoT server supports both auto-generated self-signed certificates and external certificates.

##### 🤖 Auto-Generated Certificates (Default)

When `ENABLE_DOT_SERVER=true`, the container automatically generates a self-signed certificate:

```yaml
services:
  unbound:
    environment:
      - ENABLE_DOT_SERVER=true
      - TLS_CERT_DOMAIN=my-dns.local  # Optional: custom domain
```

**Extract and trust the auto-generated certificate:**

```bash
# Extract certificate from container
docker-compose exec unbound cat /etc/unbound/tls/server.pem > unbound-dot.crt

# Add to trusted certificates (Arch Linux)
sudo cp unbound-dot.crt /etc/ca-certificates/trust-source/anchors/
sudo trust extract-compat

# Add to trusted certificates (Ubuntu/Debian)
sudo cp unbound-dot.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Add to trusted certificates (CentOS/RHEL)
sudo cp unbound-dot.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

##### 📁 External Certificates (Production)

For production use with valid certificates (Let's Encrypt, commercial CA, etc.):

```yaml
services:
  unbound:
    volumes:
      - /path/to/certs:/etc/ssl/private:ro
    environment:
      - ENABLE_DOT_SERVER=true
      - TLS_SERVICE_KEY=/etc/ssl/private/server.key
      - TLS_SERVICE_PEM=/etc/ssl/private/server.crt
      - TLS_PORT=853
```

**Example with Let's Encrypt certificates:**

```yaml
services:
  unbound:
    volumes:
      - /etc/letsencrypt/live/dns.example.com:/etc/ssl/certs:ro
    environment:
      - ENABLE_DOT_SERVER=true
      - TLS_SERVICE_KEY=/etc/ssl/certs/privkey.pem
      - TLS_SERVICE_PEM=/etc/ssl/certs/fullchain.pem
```

**Example with custom certificate directory:**

```bash
# Create certificate directory
mkdir -p ./certs

# Copy your certificates
cp your-server.key ./certs/
cp your-server.crt ./certs/

# Use in docker-compose
```

```yaml
services:
  unbound:
    volumes:
      - ./certs:/etc/unbound/certs:ro
    environment:
      - ENABLE_DOT_SERVER=true
      - TLS_SERVICE_KEY=/etc/unbound/certs/your-server.key
      - TLS_SERVICE_PEM=/etc/unbound/certs/your-server.crt
```

##### 🔧 Pre-Generated Certificates Workflow

For production environments, you may want to generate certificates beforehand and mount them:

###### Step 1: Generate certificates outside container

```bash
# Create certificate directory
mkdir -p ./certs

# Generate private key
openssl genrsa -out ./certs/server.key 2048

# Generate certificate signing request
openssl req -new -key ./certs/server.key -out ./certs/server.csr \
  -subj "/C=US/ST=Local/L=Local/O=Unbound/CN=my-dns.local"

# Generate self-signed certificate with SAN
openssl x509 -req -in ./certs/server.csr -signkey ./certs/server.key \
  -out ./certs/server.pem -days 365 \
  -extensions v3_req -extfile <(echo "[v3_req]"; echo "subjectAltName = DNS:my-dns.local,DNS:*.local,IP:127.0.0.1,IP:0.0.0.0")

# Set proper permissions
chmod 600 ./certs/server.key
chmod 644 ./certs/server.pem

# Clean up CSR
rm ./certs/server.csr
```

###### Step 2: Add certificate to system trust store

```bash
# Copy certificate to trusted store (Arch Linux)
sudo cp ./certs/server.pem /etc/ca-certificates/trust-source/anchors/unbound-dot.crt
sudo trust extract-compat

# Copy certificate to trusted store (Ubuntu/Debian)
sudo cp ./certs/server.pem /usr/local/share/ca-certificates/unbound-dot.crt
sudo update-ca-certificates

# Copy certificate to trusted store (CentOS/RHEL)
sudo cp ./certs/server.pem /etc/pki/ca-trust/source/anchors/unbound-dot.crt
sudo update-ca-trust
```

###### Step 3: Mount certificates in docker-compose

```yaml
services:
  unbound:
    build: .
    ports:
      - "53:53/udp"
      - "853:853/tcp"
    volumes:
      - ./certs/server.key:/etc/unbound/tls/server.key:ro
      - ./certs/server.pem:/etc/unbound/tls/server.pem:ro
    environment:
      - ENABLE_DOT_SERVER=true
      - TLS_SERVICE_KEY=/etc/unbound/tls/server.key
      - TLS_SERVICE_PEM=/etc/unbound/tls/server.pem
    restart: unless-stopped
```

###### Step 4: Test with certificate validation

```bash
# Test DoT with certificate validation
kdig @127.0.0.1 -p 853 +tls-ca +tls-host=my-dns.local google.com

# Configure systemd-resolved
sudo resolvectl dns 127.0.0.1#853
sudo resolvectl dnsovertls yes
```

#### 🧪 Testing DoT Server

```bash
# Test with kdig (requires knot-dnsutils)
kdig @127.0.0.1 -p 853 +tls google.com

# Test with certificate validation (after adding to trusted store)
kdig @127.0.0.1 -p 853 +tls-ca +tls-host=localhost google.com

# Configure systemd-resolved to use DoT
sudo resolvectl dns 127.0.0.1#853
sudo resolvectl dnsovertls yes
```

#### 🔧 systemd-resolved Integration

To configure systemd-resolved to use your DoT server:

```bash
# Set DNS server with DoT port
sudo resolvectl dns 127.0.0.1#853

# Enable DoT globally
sudo resolvectl dnsovertls yes

# Verify configuration
resolvectl status
```

**Note:** systemd-resolved requires trusted certificates. Make sure to add the self-signed certificate to your system's trust store as shown above.

### ⚡ Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `NUM_THREADS` | `1` | Number of worker threads |
| `MSG_BUFFER_SIZE` | `65552` | Message buffer size |
| `MSG_CACHE_SIZE` | `4m` | Message cache size |
| `RRSET_CACHE_SIZE` | `4m` | RRset cache size |
| `CACHE_TTL` | `86400` | Maximum cache TTL (seconds) |
| `PREFETCH` | `yes` | Enable cache prefetching |
| `PREFETCH_KEY` | `yes` | Enable DNSSEC key prefetching |

### 🔐 Security Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `HIDE_IDENTITY` | `yes` | Hide server identity |
| `HIDE_VERSION` | `yes` | Hide server version |
| `BLOCK_PRIVATE` | `true` | Block private addresses in responses |
| `PRIVATE_ADDRESS` | `192.168.0.0/16` | Private address range 1 |
| `PRIVATE_ADDRESS2` | `172.16.0.0/12` | Private address range 2 |
| `PRIVATE_ADDRESS3` | `10.0.0.0/8` | Private address range 3 |

#### Security Settings Explained

##### HIDE_IDENTITY and HIDE_VERSION

These settings prevent information disclosure about your DNS server:

```bash
HIDE_IDENTITY=yes
HIDE_VERSION=yes
```

**Without hiding (unsafe):**

```bash
$ dig @your-server version.bind chaos txt
version.bind. 0 CH TXT "unbound 1.23.0"

$ dig @your-server hostname.bind chaos txt
hostname.bind. 0 CH TXT "dns-server.example.com"
```

**With hiding enabled:** These queries return no information, preventing attackers from identifying your server software and version.

##### BLOCK_PRIVATE and Private Address Ranges

This protects against DNS Rebinding attacks where malicious domains return private IP addresses:

```bash
BLOCK_PRIVATE=true
PRIVATE_ADDRESS=192.168.0.0/16
PRIVATE_ADDRESS2=172.16.0.0/12
PRIVATE_ADDRESS3=10.0.0.0/8
```

**How it works:**

- Attacker creates `evil.com` that returns `192.168.1.1` (your router)
- With `BLOCK_PRIVATE=true`: Unbound blocks this response
- Without protection: Your browser might connect to internal devices

**When to disable BLOCK_PRIVATE:**

Set `BLOCK_PRIVATE=false` when you need internal domains to work:

```bash
# Example: Internal services
app.local → 192.168.1.100
router.local → 192.168.1.1
nas.home → 10.0.0.50
```

**Custom private ranges:**

You can define custom private networks:

```bash
BLOCK_PRIVATE=true
PRIVATE_ADDRESS=10.10.0.0/16      # Your corporate network
PRIVATE_ADDRESS2=192.168.100.0/24 # Guest network
PRIVATE_ADDRESS3=172.20.0.0/16    # VPN network
```

#### Security Configuration Examples

**Maximum security (public DNS):**

```bash
HIDE_IDENTITY=yes
HIDE_VERSION=yes
BLOCK_PRIVATE=true
ACCESS_CONTROL_CUSTOM="trusted-networks-only"
```

**Home network with internal services:**

```bash
HIDE_IDENTITY=yes
HIDE_VERSION=yes
BLOCK_PRIVATE=false  # Allow internal domains
ACCESS_CONTROL_CUSTOM="192.168.0.0/16 allow,127.0.0.0/8 allow,0.0.0.0/0 deny"
```

**Corporate environment:**

```bash
HIDE_IDENTITY=yes
HIDE_VERSION=yes
BLOCK_PRIVATE=true
PRIVATE_ADDRESS=10.0.0.0/8        # Block external private ranges
PRIVATE_ADDRESS2=192.168.0.0/16   # But allow corporate networks
PRIVATE_ADDRESS3=172.16.0.0/12    # in ACCESS_CONTROL_CUSTOM
```

**Development/testing:**

```bash
HIDE_IDENTITY=no   # Allow debugging
HIDE_VERSION=no    # Allow version checks
BLOCK_PRIVATE=false # Allow all internal IPs
ACCESS_CONTROL_CUSTOM="127.0.0.0/8 allow,0.0.0.0/0 deny"
```

### 📊 Logging Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `1` | Verbosity level (0-5) |
| `LOG_QUERIES` | `no` | Log DNS queries |
| `LOG_REPLIES` | `no` | Log DNS replies |

## 🚀 Configuration Examples by Use Case

### 🏠 Basic Home DNS Server

```yaml
services:
  unbound:
    build: .
    ports:
      - "53:53/udp"
      - "853:853/tcp"  # DoT server
    environment:
      - UPSTREAM_SERVERS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
      - ACCESS_CONTROL_CUSTOM=192.168.0.0/16 allow,127.0.0.0/8 allow,0.0.0.0/0 deny
      - ENABLE_DOT=true
      - ENABLE_DOT_SERVER=true
      - ENABLE_DNSSEC=true
      - HIDE_IDENTITY=yes
      - HIDE_VERSION=yes
      - BLOCK_PRIVATE=true
    restart: unless-stopped
```

### 💻 Local Development with Docker-gen-dns

For developers using local DNS resolution or similar tools for local domain resolution:

```yaml
services:
  unbound:
    build: .
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    environment:
      # Forward *.local domains to local DNS resolution
      - LOCAL_DOMAINS=local:127.0.0.1:5353
      
      # Upstream servers with DoT and custom domains
      - UPSTREAM_DNS_1=1.1.1.1@853#cloudflare-dns.com
      - UPSTREAM_DNS_2=8.8.8.8@853#dns.google
      
      # Allow localhost + Docker containers
      - ACCESS_CONTROL_CUSTOM=127.0.0.0/8 allow,172.16.0.0/12 allow,0.0.0.0/0 deny
      
      # Must disable to allow internal IPs from local DNS resolution
      - BLOCK_PRIVATE=false
      
      # Security
      - HIDE_IDENTITY=yes
      - HIDE_VERSION=yes
      
      # Features
      - ENABLE_DOT=true
      - ENABLE_DNSSEC=true
      - ENABLE_CACHE=true
    restart: unless-stopped
```

**How this works:**

- `app.local` → forwarded to local DNS resolution at `127.0.0.1:5353`
- `google.com` → forwarded to upstream DNS servers via DoT (1.1.1.1@853#cloudflare-dns.com, 8.8.8.8@853#dns.google)
- Docker containers can query DNS (172.16.0.0/12 network allowed)
- External access blocked for security

**Custom DoT server example:**

```yaml
environment:
  - LOCAL_DOMAINS=local:127.0.0.1:5353
  - UPSTREAM_DNS_1=your-dns.example.com@853#your-dns.example.com
  - UPSTREAM_DNS_2=1.1.1.1@853#cloudflare-dns.com
  - ACCESS_CONTROL_CUSTOM=127.0.0.0/8 allow,172.16.0.0/12 allow,0.0.0.0/0 deny
  - BLOCK_PRIVATE=false
  - ENABLE_DOT=true
```

### 🏢 Corporate Network

```yaml
services:
  unbound:
    build: .
    ports:
      - "53:53/udp"
      - "853:853/tcp"  # DoT server
    environment:
      # Network access
      - INTERFACE=0.0.0.0
      - ACCESS_CONTROL_CUSTOM=10.0.0.0/8 allow,192.168.0.0/16 allow,172.16.0.0/12 allow,0.0.0.0/0 deny
      
      # Internal domains
      - LOCAL_DOMAINS=corp:10.0.0.1:53,internal:192.168.1.1:53
      
      # Upstream
      - UPSTREAM_SERVERS=1.1.1.1 8.8.8.8 9.9.9.9
      
      # Security (strict)
      - HIDE_IDENTITY=yes
      - HIDE_VERSION=yes
      - BLOCK_PRIVATE=true
      
      # Features
      - ENABLE_DOT=true
      - ENABLE_DOT_SERVER=true
      - ENABLE_DNSSEC=true
      - ENABLE_LOGGING=true
      
      # Performance
      - NUM_THREADS=4
      - MSG_CACHE_SIZE=32m
      - RRSET_CACHE_SIZE=32m
      
      # Logging
      - LOG_LEVEL=2
      - LOG_QUERIES=yes
    restart: unless-stopped
```

### 🧪 Testing/Development Environment

```yaml
services:
  unbound:
    build: .
    ports:
      - "5353:53/udp"  # Non-privileged port
      - "5353:53/tcp"
    environment:
      # Localhost only
      - ACCESS_CONTROL_CUSTOM=127.0.0.0/8 allow,0.0.0.0/0 deny
      
      # Test domains
      - LOCAL_DOMAINS=test:127.0.0.1:8053,dev:127.0.0.1:9053
      
      # Upstream
      - UPSTREAM_SERVERS=8.8.8.8 1.1.1.1
      
      # Relaxed security for debugging
      - HIDE_IDENTITY=no
      - HIDE_VERSION=no
      - BLOCK_PRIVATE=false
      
      # Debug logging
      - ENABLE_LOGGING=true
      - LOG_LEVEL=3
      - LOG_QUERIES=yes
      - LOG_REPLIES=yes
      
      # Features
      - ENABLE_DOT=true
      - ENABLE_DNSSEC=true
    restart: unless-stopped
```

## 🧪 Testing

### 🔍 Test DNS Resolution

```bash
# Test basic DNS
dig @localhost google.com

# Test with specific record type
dig @localhost MX google.com

# Test DNSSEC
dig @localhost +dnssec google.com

# Test local domains
dig @localhost test.local
```

### 🔒 Test DoT Server

```bash
# Install kdig (if not available)
# Arch Linux: sudo pacman -S knot
# Ubuntu/Debian: sudo apt install knot-dnsutils
# CentOS/RHEL: sudo yum install knot-utils

# Test DoT without certificate validation
kdig @127.0.0.1 -p 853 +tls google.com

# Test DoT with certificate validation (after adding cert to trust store)
kdig @127.0.0.1 -p 853 +tls-ca +tls-host=localhost google.com

# Test DoT with local domains
kdig @127.0.0.1 -p 853 +tls test.local

# Test DoT with DNSSEC
kdig @127.0.0.1 -p 853 +tls +dnssec cloudflare.com
```

## 🔧 Troubleshooting

### 🐛 Enable Debug Logging

```bash
docker run -e ENABLE_LOGGING=true -e LOG_LEVEL=3 your-registry/unbound:latest
```

### ⚙️ Check Configuration

The generated configuration will be displayed in logs when `ENABLE_LOGGING=true`.

### ⚠️ Common Issues

1. **Permission denied on port 53**: Run with `--privileged` or use a port > 1024
2. **Upstream connection failures**: Check firewall rules for ports 53, 853
3. **DNSSEC validation failures**: Check system time and upstream DNSSEC support
4. **DoT certificate errors**: Add self-signed certificate to system trust store
5. **systemd-resolved DoT issues**: Ensure certificate is trusted and use `127.0.0.1#853`

### 🔒 DoT Server Troubleshooting

**Certificate validation errors:**

```bash
# Check if certificate is properly generated
docker-compose exec unbound ls -la /etc/unbound/tls/

# Test DoT without certificate validation
kdig @127.0.0.1 -p 853 +tls google.com

# Check if certificate is in trust store
trust list | grep -i unbound
```

**systemd-resolved not using DoT:**

```bash
# Check current DNS configuration
resolvectl status

# Force DoT usage
sudo resolvectl dns 127.0.0.1#853
sudo resolvectl dnsovertls yes

# Verify DoT is working
resolvectl query google.com
```

## 🔐 Security Considerations

- Restrict access using `ACCESS_CONTROL_CUSTOM` in production
- Enable DNSSEC validation for enhanced security
- Use DNS-over-TLS for upstream queries
- Regularly update the container image for security patches

## 📄 License

This project is dual-licensed under either of:

- 🔓 **Apache License, Version 2.0** ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- 🔓 **MIT License** ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

### 📦 Third-Party Components

This project includes and is based on the following third-party software:

#### 🌐 Unbound DNS Server

- **Copyright**: Copyright (c) NLnet Labs. All rights reserved.
- **License**: BSD 3-Clause "New" or "Revised" License
- **Source**: <https://github.com/NLnetLabs/unbound>
- **Description**: High-performance DNS resolver

#### 🏔️ Alpine Linux

- **Copyright**: Copyright (c) Alpine Linux Development Team
- **License**: MIT License
- **Source**: <https://alpinelinux.org/>
- **Description**: Security-oriented, lightweight Linux distribution

### ⚖️ License Compliance

The configuration files, scripts, and documentation in this repository are original works licensed under Apache 2.0 OR MIT. The underlying Unbound software and Alpine Linux base image retain their respective licenses (BSD 3-Clause and MIT).

### 📋 BSD 3-Clause License Notice

Redistribution and use of Unbound in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

### 🤝 Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this project by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
