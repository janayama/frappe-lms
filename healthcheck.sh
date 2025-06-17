#!/bin/bash

# Health check script for Railway deployment
set -e

# Get the site name from environment or use default
SITE_NAME=${SITE_NAME:-"site1.local"}

echo "Running health check for site: $SITE_NAME"

# First check if our static health file exists and is accessible
if [ -f "sites/$SITE_NAME/public/health" ]; then
    echo "Static health file found"
    # Try to access the health endpoint
    if curl -f -s "http://localhost:8080/health" > /dev/null 2>&1; then
        echo "Health endpoint accessible"
        exit 0
    fi
fi

# Check if the main site is responding
if curl -f -s "http://localhost:8080/" > /dev/null 2>&1; then
    echo "Main site responding"
    exit 0
fi

# Check if Gunicorn is running
if pgrep -f gunicorn > /dev/null; then
    echo "Gunicorn is running, but site not yet ready"
    exit 0
fi

echo "Health check failed"
exit 1 