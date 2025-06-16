#!/bin/bash

# Health check script for Frappe LMS on Railway
PORT=${PORT:-8000}

# Try multiple endpoints in order of preference
endpoints=(
    "/"
    "/api/method/ping"
    "/api/method/frappe.ping"
)

for endpoint in "${endpoints[@]}"; do
    if curl -f -s --max-time 15 "http://localhost:$PORT$endpoint" > /dev/null 2>&1; then
        echo "Health check passed - endpoint $endpoint responding"
        exit 0
    fi
done

echo "Health check failed - no endpoints responding"
exit 1 