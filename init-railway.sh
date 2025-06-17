#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Frappe LMS Railway Production Setup ==="

# Set environment variables with defaults for Railway
export SITE_NAME="${SITE_NAME:-lms.railway.app}"
export DB_HOST="${MYSQLHOST:-localhost}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_NAME="${MYSQLDATABASE:-railway}"
export DB_USER="${MYSQLUSER}"
export DB_PASSWORD="${MYSQLPASSWORD}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
export APP_PORT="${PORT:-8000}"

# 1. Start Redis Server in the background
echo "Starting Redis server..."
redis-server --daemonize yes
echo "Redis started."

# 2. Wait for Database to be ready
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Database not ready, retrying in 2 seconds..."
    sleep 2
done
echo "Database connection successful!"

# 3. Initialize Frappe Bench if it doesn't exist
if [ ! -d "frappe-bench" ]; then
    echo "Creating new Frappe bench..."
    bench init --skip-redis-config-generation frappe-bench
fi
cd frappe-bench

# 4. Configure bench for our environment
echo "Configuring bench..."
bench set-config -g db_host "$DB_HOST"
bench set-config -g db_port "$DB_PORT"
bench set-redis-cache-host "redis://localhost:6379"
bench set-redis-queue-host "redis://localhost:6379"
bench set-redis-socketio-host "redis://localhost:6379"
echo "Bench configuration complete."

# 5. Create the site if it doesn't exist
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Site '$SITE_NAME' not found. Creating it..."

    # Get LMS app if it's not already there
    if [ ! -d "apps/lms" ]; then
        echo "Getting LMS app..."
        bench get-app lms
    fi
    
    # Use 'bench new-site' which is the correct way to create a site and admin user
    bench new-site "$SITE_NAME" \
        --db-type mysql \
        --db-host "$DB_HOST" \
        --db-port "$DB_PORT" \
        --db-name "$DB_NAME" \
        --db-user "$DB_USER" \
        --db-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --force

    # Install the LMS app on the new site.
    echo "Installing LMS app on site..."
    bench --site "$SITE_NAME" install-app lms
    
    # Finalize site setup
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" clear-cache
    echo "Site '$SITE_NAME' created successfully."
else
    echo "Site '$SITE_NAME' already exists. Skipping creation."
fi

# 6. Start the production server using gunicorn directly
echo "Starting Gunicorn production server on port $APP_PORT..."
exec gunicorn \
    --bind="0.0.0.0:$APP_PORT" \
    --workers=2 \
    --threads=4 \
    --worker-class=gthread \
    --preload \
    frappe.app:application 