#!/bin/bash

# Health check script for Frappe LMS on Railway
PORT=${PORT:-8000}

# Simple health check - just verify the application is responding
if curl -f -s --max-time 15 "http://localhost:$PORT/api/method/ping" > /dev/null 2>&1; then
    echo "Health check passed - application responding"
    exit 0
else
    echo "Health check failed - application not responding"
    exit 1
fi 