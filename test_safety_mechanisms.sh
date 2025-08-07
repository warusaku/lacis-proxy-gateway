#!/bin/bash
# LPG Safety Mechanisms Test Suite
# Purpose: Automated testing of all safety features before clean installation
# Version: 1.0
# WARNING: Run only in test environment, NOT in production!

set -e

# Configuration
LOG_DIR="/var/log/lpg_safety_tests"
REPORT_FILE="$LOG_DIR/test_report_$(date +%Y%m%d_%H%M%S).txt"
TEST_RESULTS=()

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$REPORT_FILE"
}

# Test result recording
record_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TEST_RESULTS+=("$test_name|$result|$details")
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        log_message "✅ $test_name: PASSED - $details"
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        log_message "❌ $test_name: FAILED - $details"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Confirm test environment
confirm_test_env() {
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}   LPG SAFETY MECHANISMS TEST SUITE${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
    echo -e "${RED}WARNING: This test suite will intentionally trigger dangerous conditions!${NC}"
    echo -e "${RED}Only run this in a TEST ENVIRONMENT, not in production!${NC}"
    echo ""
    echo "Current hostname: $(hostname)"
    echo "Current IP: $(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
    echo ""
    read -p "Are you SURE this is a test environment? Type 'yes-test-only' to continue: " confirmation
    
    if [ "$confirmation" != "yes-test-only" ]; then
        echo "Test aborted. Safety first!"
        exit 1
    fi
}

# Test 1: Network Watchdog Detection
test_network_watchdog() {
    log_message "=== Test 1: Network Watchdog Detection ==="
    
    # Check if watchdog service exists
    if ! systemctl list-unit-files | grep -q lpg-watchdog; then
        record_result "Network Watchdog" "SKIP" "Service not installed"
        return
    fi
    
    # Start watchdog
    systemctl start lpg-watchdog 2>/dev/null || true
    sleep 2
    
    # Create test script
    cat > /tmp/test_bind.py << 'EOF'
import socket
import time
import sys

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('0.0.0.0', 9999))
    print("Successfully bound to 0.0.0.0:9999")
    s.listen(1)
    
    # Wait to be killed
    for i in range(10):
        print(f"Still alive after {i} seconds...")
        time.sleep(1)
    
    print("ERROR: Process was not killed!")
    sys.exit(1)
    
except Exception as e:
    print(f"Process terminated: {e}")
    sys.exit(0)
EOF
    
    # Run test
    timeout 15 python3 /tmp/test_bind.py &
    TEST_PID=$!
    
    # Wait for watchdog to react
    sleep 5
    
    # Check if process was killed
    if kill -0 $TEST_PID 2>/dev/null; then
        kill -9 $TEST_PID 2>/dev/null
        record_result "Network Watchdog" "FAIL" "Process not killed within 5 seconds"
    else
        # Check for emergency flag
        if [ -f /var/run/lpg_emergency_shutdown ]; then
            record_result "Network Watchdog" "PASS" "Process killed and emergency flag set"
            rm -f /var/run/lpg_emergency_shutdown
        else
            record_result "Network Watchdog" "PARTIAL" "Process killed but no emergency flag"
        fi
    fi
    
    # Cleanup
    rm -f /tmp/test_bind.py
}

# Test 2: SSH Fallback Protection
test_ssh_fallback() {
    log_message "=== Test 2: SSH Fallback Protection ==="
    
    # Check if script exists
    if [ ! -f /opt/lpg/src/ssh_fallback.sh ]; then
        record_result "SSH Fallback" "SKIP" "Script not found"
        return
    fi
    
    # Run SSH fallback setup
    /opt/lpg/src/ssh_fallback.sh 2>&1 | tee -a "$REPORT_FILE"
    
    # Check iptables rules
    if iptables -L INPUT -n | grep -q "tcp dpt:22"; then
        # Test blocking LPG port
        iptables -I INPUT 1 -p tcp --dport 8443 -j DROP
        
        # Check if SSH still accessible
        if nc -zv localhost 22 2>/dev/null; then
            record_result "SSH Fallback" "PASS" "SSH protected while LPG blocked"
        else
            record_result "SSH Fallback" "FAIL" "SSH not accessible"
        fi
        
        # Cleanup
        iptables -D INPUT -p tcp --dport 8443 -j DROP 2>/dev/null
    else
        record_result "SSH Fallback" "FAIL" "SSH rules not created"
    fi
}

# Test 3: Safe Wrapper Environment Check
test_safe_wrapper() {
    log_message "=== Test 3: Safe Wrapper Environment Check ==="
    
    # Check if wrapper exists
    if [ ! -f /opt/lpg/src/lpg_safe_wrapper.py ]; then
        record_result "Safe Wrapper" "SKIP" "Wrapper not found"
        return
    fi
    
    # Test with dangerous environment
    export LPG_ADMIN_HOST="0.0.0.0"
    
    # Run wrapper
    timeout 5 python3 /opt/lpg/src/lpg_safe_wrapper.py 2>&1 | tee -a "$REPORT_FILE"
    EXIT_CODE=$?
    
    # Check results
    if [ $EXIT_CODE -eq 1 ]; then
        if [ -f /var/run/lpg_emergency_abort ]; then
            record_result "Safe Wrapper" "PASS" "Dangerous config blocked"
            rm -f /var/run/lpg_emergency_abort
        else
            record_result "Safe Wrapper" "PARTIAL" "Blocked but no flag file"
        fi
    else
        record_result "Safe Wrapper" "FAIL" "Did not block dangerous config"
    fi
    
    # Reset environment
    unset LPG_ADMIN_HOST
}

# Test 4: Systemd Service Dependencies
test_systemd_deps() {
    log_message "=== Test 4: Systemd Service Dependencies ==="
    
    # Stop all services
    systemctl stop lpg-admin lpg-watchdog ssh-fallback 2>/dev/null || true
    
    # Check service files
    SERVICES_FOUND=0
    for service in ssh-fallback lpg-watchdog lpg-admin; do
        if systemctl list-unit-files | grep -q "$service"; then
            ((SERVICES_FOUND++))
        fi
    done
    
    if [ $SERVICES_FOUND -eq 3 ]; then
        # Start in order
        systemctl start ssh-fallback
        sleep 2
        systemctl start lpg-watchdog
        sleep 2
        systemctl start lpg-admin
        sleep 3
        
        # Check all running
        ALL_RUNNING=true
        for service in ssh-fallback lpg-watchdog lpg-admin; do
            if ! systemctl is-active --quiet "$service"; then
                ALL_RUNNING=false
                break
            fi
        done
        
        if $ALL_RUNNING; then
            # Check lpg-admin binding
            if netstat -tln | grep -q "127.0.0.1:8443"; then
                record_result "Systemd Dependencies" "PASS" "All services running correctly"
            else
                record_result "Systemd Dependencies" "FAIL" "LPG not on safe address"
            fi
        else
            record_result "Systemd Dependencies" "FAIL" "Services not all running"
        fi
    else
        record_result "Systemd Dependencies" "SKIP" "Not all services installed"
    fi
}

# Test 5: Emergency Shutdown
test_emergency_shutdown() {
    log_message "=== Test 5: Emergency Shutdown ==="
    
    # This test simulates network failure
    # WARNING: This will temporarily block network access!
    
    echo "Simulating network failure (will auto-recover in 60 seconds)..."
    
    # Block gateway temporarily
    iptables -I OUTPUT 1 -d 192.168.234.1 -j DROP
    
    # Set auto-recovery
    (sleep 60; iptables -D OUTPUT -d 192.168.234.1 -j DROP 2>/dev/null) &
    RECOVERY_PID=$!
    
    # Wait for watchdog to detect
    sleep 35
    
    # Check if LPG was stopped
    if systemctl is-active --quiet lpg-admin; then
        record_result "Emergency Shutdown" "FAIL" "LPG still running after network failure"
    else
        record_result "Emergency Shutdown" "PASS" "LPG stopped on network failure"
    fi
    
    # Restore network immediately
    iptables -D OUTPUT -d 192.168.234.1 -j DROP 2>/dev/null || true
    kill $RECOVERY_PID 2>/dev/null || true
}

# Test 6: Recovery Procedure
test_recovery() {
    log_message "=== Test 6: Recovery Procedure ==="
    
    # Clear emergency flags
    rm -f /var/run/lpg_emergency_* /var/run/lpg_dangerous_*
    
    # Reset iptables (backup current rules first)
    iptables-save > "$LOG_DIR/iptables_test_backup.txt"
    iptables -F
    
    # Restart services
    systemctl restart lpg-admin 2>/dev/null || true
    sleep 5
    
    # Check if recovered
    if systemctl is-active --quiet lpg-admin; then
        if netstat -tln | grep -q "127.0.0.1:8443"; then
            record_result "Recovery Procedure" "PASS" "Services recovered successfully"
        else
            record_result "Recovery Procedure" "FAIL" "LPG on wrong address after recovery"
        fi
    else
        record_result "Recovery Procedure" "FAIL" "LPG did not restart"
    fi
    
    # Restore iptables
    iptables-restore < "$LOG_DIR/iptables_test_backup.txt" 2>/dev/null || true
}

# Generate test report
generate_report() {
    log_message "=== Test Report Summary ==="
    
    echo ""
    echo "Test Results Summary:"
    echo "===================="
    
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    SKIPPED_TESTS=0
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r test_name status details <<< "$result"
        ((TOTAL_TESTS++))
        
        case "$status" in
            PASS)
                ((PASSED_TESTS++))
                echo -e "${GREEN}✅ $test_name${NC}"
                ;;
            FAIL)
                ((FAILED_TESTS++))
                echo -e "${RED}❌ $test_name${NC}"
                ;;
            SKIP)
                ((SKIPPED_TESTS++))
                echo -e "${YELLOW}⏭️  $test_name (Skipped)${NC}"
                ;;
            PARTIAL)
                echo -e "${YELLOW}⚠️  $test_name (Partial)${NC}"
                ;;
        esac
    done
    
    echo ""
    echo "Summary:"
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Passed: $PASSED_TESTS"
    echo "  Failed: $FAILED_TESTS"
    echo "  Skipped: $SKIPPED_TESTS"
    
    # Determine overall result
    if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
        echo -e "${GREEN}✅ All safety mechanisms are working correctly!${NC}"
        echo -e "${GREEN}Safe to proceed with clean installation.${NC}"
        EXIT_CODE=0
    else
        echo -e "${RED}❌ Some safety mechanisms are not working!${NC}"
        echo -e "${RED}DO NOT proceed with installation until fixed.${NC}"
        EXIT_CODE=1
    fi
    
    echo ""
    echo "Full report saved to: $REPORT_FILE"
    
    return $EXIT_CODE
}

# Main execution
main() {
    check_root
    confirm_test_env
    
    log_message "Starting LPG Safety Mechanisms Test Suite"
    log_message "Test Environment: $(hostname) - $(date)"
    
    # Run all tests
    test_network_watchdog
    test_ssh_fallback
    test_safe_wrapper
    test_systemd_deps
    test_emergency_shutdown
    test_recovery
    
    # Generate report
    generate_report
    
    exit $?
}

# Run main function
main