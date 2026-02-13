#!/bin/bash

echo "======================================"
echo "Testing Docker Image: pi-k3s:test"
echo "======================================"
echo ""

# Test 1: Check if image exists
echo "[1] Checking if image exists..."
if docker images | grep -q "pi-k3s.*test"; then
    echo "✓ Image pi-k3s:test found"
else
    echo "✗ Image pi-k3s:test not found"
    exit 1
fi
echo ""

# Test 2: Start container
echo "[2] Starting container..."
docker run -d --name pi-k3s-test -p 8080:80 pi-k3s:test
sleep 10
echo "✓ Container started"
echo ""

# Test 3: Check container is running
echo "[3] Checking container status..."
if docker ps | grep -q "pi-k3s-test"; then
    echo "✓ Container is running"
else
    echo "✗ Container failed to start"
    docker logs pi-k3s-test
    docker rm -f pi-k3s-test
    exit 1
fi
echo ""

# Test 4: Test health endpoint
echo "[4] Testing health endpoint..."
sleep 5
if curl -f http://localhost:8080/up > /dev/null 2>&1; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
fi
echo ""

# Test 5: Test API endpoint
echo "[5] Testing API endpoint (POST /api/calculate)..."
RESPONSE=$(curl -s -X POST http://localhost:8080/api/calculate \
  -H "Content-Type: application/json" \
  -d '{"total_points":100000,"mode":"single"}')

if echo "$RESPONSE" | grep -q "result_pi"; then
    echo "✓ API endpoint working"
    echo "Response: $RESPONSE" | head -c 200
    echo "..."
else
    echo "✗ API endpoint failed"
    echo "Response: $RESPONSE"
fi
echo ""
echo ""

# Test 6: View logs
echo "[6] Container logs (last 20 lines):"
echo "--------------------------------------"
docker logs --tail 20 pi-k3s-test
echo "--------------------------------------"
echo ""

# Cleanup
echo "[7] Cleaning up..."
docker stop pi-k3s-test > /dev/null 2>&1
docker rm pi-k3s-test > /dev/null 2>&1
echo "✓ Cleanup complete"
echo ""

echo "======================================"
echo "All tests completed!"
echo "======================================"
