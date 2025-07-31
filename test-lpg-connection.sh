#!/bin/bash
# LPG Connection Test Script

echo "=== LPG Connection Test ==="
echo "Testing connectivity and routing"
echo ""

# Test 1: LPG Admin UI (local access)
echo "1. Testing LPG Admin UI (https://192.168.234.2:8443)..."
curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://192.168.234.2:8443/health || echo "Failed to connect"
echo ""

# Test 2: Direct access to Orange Pi 5 Plus
echo "2. Testing direct access to Orange Pi 5 Plus (http://192.168.234.10:8080)..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.168.234.10:8080 || echo "Failed to connect"
echo ""

# Test 3: LPG routing via local IP
echo "3. Testing LPG routing via local IP..."
curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://192.168.234.2/lacisstack/boards || echo "Failed to connect"
echo ""

# Test 4: LPG routing via DDNS
echo "4. Testing LPG routing via DDNS..."
curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards || echo "Failed to connect"
echo ""

# Test 5: Check LPG service status
echo "5. Checking LPG services on 192.168.234.2..."
ssh lacissystem@192.168.234.2 "sudo systemctl status caddy --no-pager | head -10" 2>/dev/null || echo "SSH connection failed"
echo ""

echo "=== Test Summary ==="
echo "If you see HTTP Status 200 or service running status, the connection is working."
echo "If you see 'Failed to connect', check the following:"
echo "- Is the target server running?"
echo "- Is the firewall configured correctly?"
echo "- Is the LPG configuration correct?"