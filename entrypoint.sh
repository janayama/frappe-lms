#!/bin/bash
set -e

# Default values
SITE_NAME=${SITE_NAME:-lms.localhost}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
DB_HOST=${MYSQLHOST:-localhost}
DB_PORT=${MYSQLPORT:-3306}
DB_NAME=${MYSQLDATABASE:-lms_db}
DB_USER=${MYSQLUSER:-root}
DB_PASSWORD=${MYSQLPASSWORD:-admin}
PORT=${PORT:-8000}

echo "Starting Frappe LMS setup..."
echo "Site: $SITE_NAME"
echo "Database Host: $DB_HOST:$DB_PORT"
echo "Database Name: $DB_NAME"

# Wait for database to be ready
echo "Waiting for database connection..."
for i in {1..30}; do
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
        echo "Database connection established!"
        break
    fi
    echo "Database not ready, waiting... (attempt $i/30)"
    sleep 10
done

# Start Redis in the background
echo "Starting Redis server..."
redis-server --daemonize yes --port 6379 --bind 127.0.0.1

# Wait for Redis to be ready
echo "Waiting for Redis..."
for i in {1..10}; do
    if redis-cli ping >/dev/null 2>&1; then
        echo "Redis is ready!"
        break
    fi
    echo "Redis not ready, waiting... (attempt $i/10)"
    sleep 2
done

# Check if bench already exists
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
    
    # Check if site already exists
    if [ ! -d "sites/$SITE_NAME" ]; then
        echo "Creating new site: $SITE_NAME"
        
        # Create the site with custom database settings
        bench new-site "$SITE_NAME" \
            --force \
            --db-host "$DB_HOST" \
            --db-port "$DB_PORT" \
            --db-name "$DB_NAME" \
            --db-user "$DB_USER" \
            --db-password "$DB_PASSWORD" \
            --admin-password "$ADMIN_PASSWORD" \
            --no-mariadb-socket
        
        echo "Installing LMS app on site..."
        bench --site "$SITE_NAME" install-app lms
        
        echo "Setting up site configuration..."
        bench --site "$SITE_NAME" set-config developer_mode 0
        bench --site "$SITE_NAME" clear-cache
    else
        echo "Site $SITE_NAME already exists, skipping creation"
    fi
    
    # Set the site as default
    bench use "$SITE_NAME"
    
    echo "Starting Frappe LMS..."
    exec bench start
else
    echo "Creating new bench..."
    
    # Set up PATH for Node.js
    export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
    
    # Initialize bench
    bench init --skip-redis-config-generation frappe-bench
    cd frappe-bench
    
    # Configure database connection
    bench set-mariadb-host "$DB_HOST"
    
    # Configure Redis
    bench set-redis-cache-host redis://localhost:6379
    bench set-redis-queue-host redis://localhost:6379
    bench set-redis-socketio-host redis://localhost:6379
    
    # Remove redis and watch from Procfile since we manage them separately
    sed -i '/redis/d' ./Procfile || true
    sed -i '/watch/d' ./Procfile || true
    
    # Get LMS app
    echo "Getting LMS app..."
    bench get-app lms https://github.com/frappe/lms.git
    
    # Create the site with custom database settings
    echo "Creating new site: $SITE_NAME"
    bench new-site "$SITE_NAME" \
        --force \
        --db-host "$DB_HOST" \
        --db-port "$DB_PORT" \
        --db-name "$DB_NAME" \
        --db-user "$DB_USER" \
        --db-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
    
    echo "Installing LMS app on site..."
    bench --site "$SITE_NAME" install-app lms
    
    echo "Setting up site configuration..."
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench --site "$SITE_NAME" clear-cache
    
    # Set the site as default
    bench use "$SITE_NAME"
    
    echo "Starting Frappe LMS..."
    exec bench start 