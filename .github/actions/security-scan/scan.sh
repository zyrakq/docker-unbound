#!/bin/bash
set -e

IMAGE_NAME="$1"
FORMAT="$2"
SEVERITY="$3"
UPLOAD_SARIF="$4"

if [ -z "$IMAGE_NAME" ] || [ -z "$FORMAT" ] || [ -z "$SEVERITY" ]; then
    echo "Usage: $0 <image_name> <format> <severity> [upload_sarif]"
    exit 1
fi

echo "🔒 Running security scan on: $IMAGE_NAME"
echo "📋 Format: $FORMAT"
echo "⚠️ Minimum severity: $SEVERITY"

# Install Trivy if not available
if ! command -v trivy >/dev/null 2>&1; then
    echo "📦 Installing Trivy..."
    sudo apt-get update
    sudo apt-get install -y wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install -y trivy
fi

# Create output directory
mkdir -p security-reports

# Run vulnerability scan
echo "🔍 Scanning for vulnerabilities..."

if [ "$FORMAT" = "sarif" ] || [ "$UPLOAD_SARIF" = "true" ]; then
    echo "📄 Generating SARIF report..."
    trivy image \
        --format sarif \
        --output security-reports/trivy-results.sarif \
        --severity "$SEVERITY" \
        "$IMAGE_NAME" || true
fi

# Run table format scan for console output
echo "📊 Vulnerability scan results:"
trivy image \
    --format table \
    --severity "$SEVERITY" \
    "$IMAGE_NAME" > security-reports/trivy-table.txt || true

# Display results
cat security-reports/trivy-table.txt

# Count vulnerabilities
VULN_COUNT=$(grep -c "CVE-" security-reports/trivy-table.txt 2>/dev/null || echo "0")

# Ensure VULN_COUNT is a valid number
if ! [[ "$VULN_COUNT" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Could not determine vulnerability count, setting to 0"
    VULN_COUNT=0
fi

echo "vulnerabilities-count=$VULN_COUNT" >> $GITHUB_OUTPUT

if [ "$VULN_COUNT" -gt 0 ]; then
    echo "⚠️ Found $VULN_COUNT vulnerabilities"
    echo "scan-result=vulnerabilities-found" >> $GITHUB_OUTPUT
else
    echo "✅ No vulnerabilities found"
    echo "scan-result=clean" >> $GITHUB_OUTPUT
fi

# Run additional security checks
echo "🔐 Additional security checks..."

# Check if running as root
if docker run --rm "$IMAGE_NAME" id | grep -q "uid=0"; then
    echo "⚠️ Container runs as root user"
else
    echo "✅ Container runs as non-root user"
fi

# Check for common security issues
echo "🔍 Checking container configuration..."
docker run --rm "$IMAGE_NAME" sh -c '
    echo "📋 Security configuration check:"
    
    # Check for sensitive files
    if [ -f /etc/passwd ]; then
        echo "  - /etc/passwd exists (normal)"
    fi
    
    # Check for writable directories
    WRITABLE_DIRS=$(find / -type d -perm -002 2>/dev/null | head -5)
    if [ -n "$WRITABLE_DIRS" ]; then
        echo "  - Found world-writable directories:"
        echo "$WRITABLE_DIRS" | sed "s/^/    /"
    fi
    
    # Check for SUID binaries
    SUID_BINS=$(find / -type f -perm -4000 2>/dev/null | head -5)
    if [ -n "$SUID_BINS" ]; then
        echo "  - Found SUID binaries:"
        echo "$SUID_BINS" | sed "s/^/    /"
    fi
' || echo "⚠️ Could not run security configuration check"

echo "🎉 Security scan completed!"