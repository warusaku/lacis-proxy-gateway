#!/usr/bin/expect -f
# Orange Pi 5 Plus Initial Setup Script
# This script automates the initial setup process

set timeout 60
set host "192.168.234.10"
set initial_pass "orangepi"
set new_root_pass "OrangePi2024!"
set username "lacissystem"
set user_pass "lacis12345@"
set full_name "Lacis System Admin"

# Stage 1: Initial SSH connection and root password change
puts "=== Connecting to Orange Pi 5 Plus ==="
spawn ssh root@$host

expect {
    "continue connecting" {
        send "yes\r"
        expect "password:"
        send "$initial_pass\r"
    }
    "password:" {
        send "$initial_pass\r"
    }
}

# Handle initial setup wizard
expect {
    "Current password:" {
        puts "\n=== Changing root password ==="
        send "$initial_pass\r"
        expect "New password:"
        send "$new_root_pass\r"
        expect "Retype new password:"
        send "$new_root_pass\r"
    }
}

# Create new user
expect {
    "Please provide a username" {
        puts "\n=== Creating user account ==="
        send "$username\r"
        expect "Create password:"
        send "$user_pass\r"
        expect "Retype password:"
        send "$user_pass\r"
        expect "Please provide your real name:"
        send "$full_name\r"
    }
}

# Language setting
expect {
    "Set user language" {
        send "n\r"
    }
}

# Wait for prompt
expect {
    "$ " {
        puts "\n=== Initial setup complete ==="
    }
    "# " {
        puts "\n=== Initial setup complete ==="
    }
}

# Exit first session
send "exit\r"
expect eof

# Stage 2: Copy setup script
puts "\n=== Copying setup script ==="
spawn scp orangepi5plus-setup.sh $username@$host:/home/$username/
expect "password:"
send "$user_pass\r"
expect eof

# Stage 3: Execute setup script
puts "\n=== Executing setup script ==="
spawn ssh $username@$host
expect "password:"
send "$user_pass\r"
expect "$ "

# Make script executable
send "chmod +x orangepi5plus-setup.sh\r"
expect "$ "

# Run setup script with sudo
send "sudo ./orangepi5plus-setup.sh\r"
expect {
    "password for $username:" {
        send "$user_pass\r"
    }
}

# Wait for setup to complete
set timeout 300
expect {
    "Next steps:" {
        puts "\n=== Setup completed successfully! ==="
    }
    timeout {
        puts "\n=== Setup timed out - check manually ==="
    }
}

# Test services
send "sudo systemctl status test-web --no-pager\r"
expect "$ "

send "sudo systemctl status test-ws --no-pager\r"
expect "$ "

# Test direct access
send "curl -s http://localhost:8080 | head -20\r"
expect "$ "

send "exit\r"
expect eof

puts "\n=== Orange Pi 5 Plus Setup Complete ==="
puts "Test server is running at:"
puts "- Direct HTTP: http://192.168.234.10:8080"
puts "- Direct WebSocket: ws://192.168.234.10:8081"
puts "- Via LPG: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards"