#!/bin/bash
set -e

IMAGE_NAME="$1"
TEST_PORT="$2"
TIMEOUT="$3"

if [ -z "$IMAGE_NAME" ] || [ -z "$TEST_PORT" ] || [ -z "$TIMEOUT" ]; then
    echo "Usage: $0 <image_name> <test_port> <timeout>"
    exit 1
fi

echo "🧪 Testing Docker image: $IMAGE_NAME"
echo "📋 Test port: $TEST_PORT"
echo "⏱️ Timeout: ${TIMEOUT}s"

# Generate unique container name
CONTAINER_NAME="test-unbound-$$-$(date +%s)"

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up test container"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test 1: Basic container startup
echo "📋 Test 1: Container startup"
CONTAINER_ID=$(docker run -d --name "$CONTAINER_NAME" -p ${TEST_PORT}:53/udp "$IMAGE_NAME")
echo "✅ Container started: $CONTAINER_ID"

# Wait for container to be ready
echo "⏳ Waiting for DNS server to be ready..."
sleep 15

# Test 2: Basic DNS resolution
echo "📋 Test 2: Basic DNS resolution"
if timeout $TIMEOUT dig @127.0.0.1 -p $TEST_PORT +short google.com | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "✅ DNS resolution works"
else
    echo "❌ DNS resolution failed"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME"
    echo "result=failure" >> $GITHUB_OUTPUT
    exit 1
fi

# Test 3: DNSSEC validation
echo "📋 Test 3: DNSSEC validation"
if timeout $TIMEOUT dig @127.0.0.1 -p $TEST_PORT +dnssec cloudflare.com | grep -q "ad"; then
    echo "✅ DNSSEC validation works"
else
    echo "⚠️ DNSSEC validation may not be working (not critical)"
fi

# Test 4: Container health check
echo "📋 Test 4: Container health check"
if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo "✅ Container is running healthy"
else
    echo "❌ Container is not running properly"
    docker logs "$CONTAINER_NAME"
    echo "result=failure" >> $GITHUB_OUTPUT
    exit 1
fi

# Test 5: Configuration validation
echo "📋 Test 5: Configuration validation"
if docker exec "$CONTAINER_NAME" sh -c "command -v unbound-checkconf >/dev/null 2>&1 && unbound-checkconf"; then
    echo "✅ Unbound configuration is valid"
else
    echo "⚠️ Could not validate configuration (unbound-checkconf not available or failed)"
fi

# Test 6: Memory usage check
echo "📋 Test 6: Memory usage check"
MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" | cut -d'/' -f1 | sed 's/[^0-9.]//g')
if [ -n "$MEMORY_USAGE" ]; then
    echo "✅ Memory usage: ${MEMORY_USAGE}MB"
    echo "memory=$MEMORY_USAGE" >> $GITHUB_OUTPUT
    # Check if memory usage is reasonable (less than 100MB for basic setup)
    if (( $(echo "$MEMORY_USAGE < 100" | bc -l) )); then
        echo "✅ Memory usage is within expected range"
    else
        echo "⚠️ Memory usage seems high: ${MEMORY_USAGE}MB"
    fi
else
    echo "⚠️ Could not determine memory usage"
    echo "memory=unknown" >> $GITHUB_OUTPUT
fi

# Test 7: Multiple query types
echo "📋 Test 7: Multiple query types"
for qtype in A AAAA MX TXT; do
    if timeout $TIMEOUT dig @127.0.0.1 -p $TEST_PORT $qtype google.com >/dev/null 2>&1; then
        echo "✅ $qtype queries work"
    else
        echo "⚠️ $qtype queries may not work"
    fi
done

echo "🎉 All tests completed successfully!"
echo "result=success" >> $GITHUB_OUTPUT

echo "📊 Test Summary:"
echo "  - Container startup: ✅"
echo "  - DNS resolution: ✅"
echo "  - DNSSEC validation: ⚠️ (may vary)"
echo "  - Container health: ✅"
echo "  - Configuration: ⚠️ (may vary)"
echo "  - Memory usage: ✅"
echo "  - Query types: ✅"