#!/bin/bash

# Exit on any error
set -e

echo "=== Frappe LMS Railway Setup ==="
echo "Site: ${SITE_NAME:-lms.railway.app}"
echo "Database: ${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}"
echo "Port: ${PORT:-8000}"

# Set environment variables with defaults
export SITE_NAME="${SITE_NAME:-lms.railway.app}"
export DB_HOST="${MYSQLHOST:-localhost}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_NAME="${MYSQLDATABASE:-railway}"
export DB_USER="${MYSQLUSER:-root}"
export DB_PASSWORD="${MYSQLPASSWORD}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
export APP_PORT="${PORT:-8000}"

# Wait for database to be ready
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Database not ready, waiting..."
    sleep 2
done
echo "Database connection successful!"

# Check if bench already exists
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, starting application..."
    cd frappe-bench
    
    # Update site configuration for Railway
    if [ -f "sites/${SITE_NAME}/site_config.json" ]; then
        echo "Updating site configuration..."
        # Update the site config with current environment variables
        python3 -c "
import json
import os

config_file = 'sites/${SITE_NAME}/site_config.json'
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Update database connection
    config.update({
        'db_host': '${DB_HOST}',
        'db_port': ${DB_PORT},
        'db_name': '${DB_NAME}',
        'db_password': '${DB_PASSWORD}'
    })
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('Site configuration updated')
"
    fi
    
    # Start the application
    echo "Starting Frappe web server..."
    # Use bench serve for single process (Railway compatible)
    # bench start runs multiple processes which doesn't work well on Railway
    bench serve --port $APP_PORT
else
    echo "Creating new bench..."
    
    # Initialize bench without Redis config (we'll configure it manually)
    bench init --skip-redis-config-generation frappe-bench
    
    cd frappe-bench
    
    # Configure database connection for Railway MySQL
    echo "Configuring database connection..."
    bench set-config -g db_host "$DB_HOST"
    bench set-config -g db_port "$DB_PORT"
    
    # Configure Redis (use localhost since we're not using containers)
    bench set-redis-cache-host redis://localhost:6379
    bench set-redis-queue-host redis://localhost:6379  
    bench set-redis-socketio-host redis://localhost:6379
    
    # Start Redis server in background
    echo "Starting Redis server..."
    redis-server --daemonize yes --port 6379 --maxmemory 256mb --maxmemory-policy allkeys-lru
    
    # Wait for Redis to start
    sleep 2
    
    # Get LMS app
    echo "Installing LMS app..."
    bench get-app lms
    
    # Create new site
    echo "Creating site: $SITE_NAME"
    bench new-site "$SITE_NAME" \
        --force \
        --db-host "$DB_HOST" \
        --db-port "$DB_PORT" \
        --db-name "$DB_NAME" \
        --db-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
    
    # Install LMS app on the site
    echo "Installing LMS app on site..."
    bench --site "$SITE_NAME" install-app lms
    
    # Configure the site
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench --site "$SITE_NAME" clear-cache
    bench use "$SITE_NAME"
    
    echo "Setup completed successfully!"
    
    # Start the application
    echo "Starting Frappe web server..."
    # Use bench serve for single process (Railway compatible)
    # bench start runs multiple processes which doesn't work well on Railway
    bench serve --port $APP_PORT
fi 