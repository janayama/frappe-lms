#!/bin/bash

# Health check script for Frappe LMS
PORT=${PORT:-8000}

# Check if the application is responding
if curl -f -s --max-time 10 "http://localhost:$PORT/api/method/ping" > /dev/null 2>&1; then
    echo "Health check passed"
    exit 0
else
    echo "Health check failed - application not responding"
    exit 1
fi 