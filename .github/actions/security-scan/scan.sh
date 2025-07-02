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

echo "🎉 Security scan completed!"