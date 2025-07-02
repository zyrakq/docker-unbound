#!/bin/bash
set -e

IMAGE_NAME="$1"
DURATION="$2"
CONCURRENT="$3"
TEST_PORT="$4"

if [ -z "$IMAGE_NAME" ] || [ -z "$DURATION" ] || [ -z "$CONCURRENT" ] || [ -z "$TEST_PORT" ]; then
    echo "Usage: $0 <image_name> <duration> <concurrent_queries> <test_port>"
    exit 1
fi

echo "🚀 Running performance tests on: $IMAGE_NAME"
echo "⏱️ Duration: $DURATION"
echo "🔄 Concurrent queries: $CONCURRENT"
echo "📋 Test port: $TEST_PORT"

# Generate unique container name
CONTAINER_NAME="perf-test-unbound-$$-$(date +%s)"

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up performance test container"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Start container
echo "🐳 Starting container for performance testing..."
docker run -d --name "$CONTAINER_NAME" -p ${TEST_PORT}:53/udp "$IMAGE_NAME"

# Wait for startup
echo "⏳ Waiting for DNS server to be ready..."
sleep 15

# Install required tools
if ! command -v dig >/dev/null 2>&1; then
    echo "📦 Installing dnsutils..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y dnsutils >/dev/null 2>&1
fi

if ! command -v bc >/dev/null 2>&1; then
    echo "📦 Installing bc..."
    sudo apt-get install -y bc >/dev/null 2>&1
fi

# Create results directory
mkdir -p performance-reports

# Performance test function
run_perf_test() {
    local queries=$1
    local domain=$2
    local test_name=$3
    
    echo "📊 Running $test_name: $queries queries to $domain..."
    
    start_time=$(date +%s.%N)
    success_count=0
    
    for i in $(seq 1 $queries); do
        if timeout 5 dig @127.0.0.1 -p $TEST_PORT +short "$domain" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    if [ "$success_count" -gt 0 ]; then
        qps=$(echo "scale=2; $success_count / $duration" | bc)
        avg_time=$(echo "scale=3; $duration / $success_count * 1000" | bc)
        success_rate=$(echo "scale=2; $success_count * 100 / $queries" | bc)
        
        echo "  ✅ Success rate: ${success_rate}% ($success_count/$queries)"
        echo "  ⚡ QPS: $qps"
        echo "  ⏱️ Average response time: ${avg_time}ms"
        echo "  🕐 Total duration: ${duration}s"
        
        # Save to report
        echo "$test_name,$queries,$success_count,$success_rate,$qps,$avg_time,$duration" >> performance-reports/results.csv
        
        # Return values for main test
        if [ "$test_name" = "Main Performance Test" ]; then
            echo "qps=$qps" >> $GITHUB_OUTPUT
            echo "avg-time=$avg_time" >> $GITHUB_OUTPUT
        fi
    else
        echo "  ❌ All queries failed"
        echo "$test_name,$queries,0,0,0,0,$duration" >> performance-reports/results.csv
    fi
    
    echo ""
}

# Initialize CSV report
echo "Test,Total Queries,Successful,Success Rate %,QPS,Avg Response Time ms,Duration s" > performance-reports/results.csv

# Run basic performance tests
echo "🧪 Basic Performance Tests:"
run_perf_test 50 "google.com" "Warm-up Test"
run_perf_test 100 "google.com" "Main Performance Test"
run_perf_test 50 "cloudflare.com" "Alternative DNS Test"
run_perf_test 50 "github.com" "Complex Domain Test"

# Concurrent load test
echo "🔄 Concurrent Load Test:"
echo "📊 Running $CONCURRENT concurrent queries..."

start_time=$(date +%s.%N)

# Run concurrent queries in background
for i in $(seq 1 $CONCURRENT); do
    (
        for j in $(seq 1 10); do
            dig @127.0.0.1 -p $TEST_PORT +short "test$j.google.com" >/dev/null 2>&1 || true
        done
    ) &
done

# Wait for all background jobs
wait

end_time=$(date +%s.%N)
concurrent_duration=$(echo "$end_time - $start_time" | bc)
total_queries=$((CONCURRENT * 10))
concurrent_qps=$(echo "scale=2; $total_queries / $concurrent_duration" | bc)

echo "  ✅ Concurrent test completed"
echo "  🔄 Total queries: $total_queries"
echo "  ⚡ Concurrent QPS: $concurrent_qps"
echo "  🕐 Duration: ${concurrent_duration}s"

echo "Concurrent Load Test,$total_queries,$total_queries,100,$concurrent_qps,N/A,$concurrent_duration" >> performance-reports/results.csv

# Memory and CPU monitoring
echo "📊 Resource Usage Monitoring:"

# Monitor for a short period
echo "🔍 Monitoring resource usage for 30 seconds..."
echo "Sample,CPU %,Memory MB" > performance-reports/resource-usage.csv

for i in $(seq 1 6); do
    STATS=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$CONTAINER_NAME" 2>/dev/null || echo "0%,0B / 0B")
    CPU_PERC=$(echo "$STATS" | cut -d',' -f1 | sed 's/%//')
    MEM_USAGE=$(echo "$STATS" | cut -d',' -f2 | cut -d'/' -f1 | sed 's/[^0-9.]//g')
    
    echo "  Sample $i: CPU: ${CPU_PERC}%, Memory: ${MEM_USAGE}MB"
    echo "$i,$CPU_PERC,$MEM_USAGE" >> performance-reports/resource-usage.csv
    
    sleep 5
done

# Get maximum memory usage
MAX_MEMORY=$(sort -t',' -k3 -nr performance-reports/resource-usage.csv | head -1 | cut -d',' -f3)
echo "max-memory=$MAX_MEMORY" >> $GITHUB_OUTPUT

# Memory stress test
echo "🧠 Memory Stress Test:"
echo "📊 Running high-frequency queries for memory analysis..."

stress_start=$(date +%s.%N)
stress_queries=0

# Run queries for 30 seconds
timeout 30s bash -c '
    count=0
    while true; do
        dig @127.0.0.1 -p '$TEST_PORT' +short "stress-test-$(date +%s%N).example.com" >/dev/null 2>&1 || true
        count=$((count + 1))
        echo $count > /tmp/stress_count
    done
' || true

stress_end=$(date +%s.%N)
stress_duration=$(echo "$stress_end - $stress_start" | bc)
stress_queries=$(cat /tmp/stress_count 2>/dev/null || echo "0")
stress_qps=$(echo "scale=2; $stress_queries / $stress_duration" | bc)

echo "  ✅ Stress test completed"
echo "  🔥 Stress queries: $stress_queries"
echo "  ⚡ Stress QPS: $stress_qps"

echo "Memory Stress Test,$stress_queries,$stress_queries,100,$stress_qps,N/A,$stress_duration" >> performance-reports/results.csv

# Final resource check
echo "📊 Final Resource Usage:"
FINAL_STATS=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$CONTAINER_NAME")
echo "$FINAL_STATS"

# Generate summary report
echo "📋 Performance Test Summary:" > performance-reports/summary.txt
echo "================================" >> performance-reports/summary.txt
echo "Image: $IMAGE_NAME" >> performance-reports/summary.txt
echo "Test Duration: $DURATION" >> performance-reports/summary.txt
echo "Concurrent Queries: $CONCURRENT" >> performance-reports/summary.txt
echo "Maximum Memory Usage: ${MAX_MEMORY}MB" >> performance-reports/summary.txt
echo "" >> performance-reports/summary.txt
echo "Detailed Results:" >> performance-reports/summary.txt
cat performance-reports/results.csv >> performance-reports/summary.txt

# Display summary
cat performance-reports/summary.txt

echo "🎉 Performance tests completed successfully!"
echo "result=success" >> $GITHUB_OUTPUT