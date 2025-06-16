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
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Database not ready, waiting..."
  sleep 5
done
echo "Database connection established!"

# Start Redis in the background
echo "Starting Redis server..."
redis-server --daemonize yes --port 6379

# Check if bench already exists
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
else
    echo "Creating new bench..."
    
    # Set up PATH for Node.js
    export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
    
    # Initialize bench
    bench init --skip-redis-config-generation frappe-bench
    cd frappe-bench
    
    # Configure database connection
    bench set-mariadb-host "$DB_HOST"
    
    # Configure Redis (use localhost for simplicity, Frappe will handle if not available)
    bench set-redis-cache-host redis://localhost:6379
    bench set-redis-queue-host redis://localhost:6379
    bench set-redis-socketio-host redis://localhost:6379
    
    # Remove redis and watch from Procfile since we're not using them
    sed -i '/redis/d' ./Procfile || true
    sed -i '/watch/d' ./Procfile || true
    
    # Get LMS app
    echo "Getting LMS app..."
    bench get-app lms https://github.com/frappe/lms.git
fi

# Ensure we're in the bench directory
cd /home/frappe/frappe-bench

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
    
    # Set the site as default
    bench use "$SITE_NAME"
else
    echo "Site $SITE_NAME already exists, skipping creation"
    bench use "$SITE_NAME"
fi

# Run migrations if needed
echo "Running migrations..."
bench --site "$SITE_NAME" migrate

# Start the application
echo "Starting Frappe LMS on port $PORT..."
exec bench serve --site "$SITE_NAME" --port "$PORT" --host 0.0.0.0 