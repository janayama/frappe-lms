#!/bin/bash

# Health check script for Frappe LMS
PORT=${PORT:-8000}
SITE_NAME=${SITE_NAME:-lms.localhost}

# Check if the application is responding
if curl -f -s "http://localhost:$PORT/api/method/ping" > /dev/null; then
    echo "✅ Application is healthy"
    exit 0
else
    echo "❌ Application health check failed"
    
    # Additional checks
    echo "Checking if bench process is running..."
    if pgrep -f "bench" > /dev/null; then
        echo "✅ Bench process is running"
    else
        echo "❌ Bench process is not running"
    fi
    
    echo "Checking if site exists..."
    if [ -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
        echo "✅ Site directory exists"
    else
        echo "❌ Site directory does not exist"
    fi
    
    exit 1
fi 