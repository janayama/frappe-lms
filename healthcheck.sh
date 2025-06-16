#!/bin/bash

# Health check script for Frappe LMS Production
PORT=${PORT:-8000}

# Function to check if the application is responding
check_app_health() {
    # Try multiple endpoints to ensure the app is truly healthy
    local endpoints=(
        "/api/method/ping"
        "/api/method/frappe.ping"
        "/"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f -s --max-time 10 "http://localhost:$PORT$endpoint" > /dev/null 2>&1; then
            echo "Health check passed - endpoint $endpoint responding"
            return 0
        fi
    done
    
    return 1
}

# Check if gunicorn process is running
check_process() {
    if pgrep -f "gunicorn.*frappe.app:application" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Main health check logic
if check_process; then
    if check_app_health; then
        echo "Health check passed - application is healthy"
        exit 0
    else
        echo "Health check failed - application process running but not responding"
        exit 1
    fi
else
    echo "Health check failed - application process not running"
    exit 1
fi 