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

echo "=== Frappe LMS Production Startup ==="
echo "Site: $SITE_NAME"
echo "Database Host: $DB_HOST:$DB_PORT"
echo "Database Name: $DB_NAME"
echo "Port: $PORT"

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local check_command=$2
    local max_attempts=$3
    local attempt=1
    
    echo "Waiting for $service_name..."
    while [ $attempt -le $max_attempts ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            echo "$service_name is ready!"
            return 0
        fi
        echo "$service_name not ready, waiting... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: $service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Wait for database
wait_for_service "Database" \
    "mysql -h\"$DB_HOST\" -P\"$DB_PORT\" -u\"$DB_USER\" -p\"$DB_PASSWORD\" -e \"SELECT 1\"" \
    30

# Start Redis in the background
echo "Starting Redis server..."
redis-server --daemonize yes --port 6379 --bind 127.0.0.1 --maxmemory 256mb --maxmemory-policy allkeys-lru

# Wait for Redis
wait_for_service "Redis" \
    "redis-cli ping" \
    10

# Ensure we're in the correct directory
cd /home/frappe

# Check if bench directory exists, if not create it
if [ ! -d "frappe-bench" ]; then
    echo "Creating new bench..."
    
    # Initialize bench
    bench init --skip-redis-config-generation --python python3 frappe-bench
    cd frappe-bench
    
    # Configure database connection
    bench set-mariadb-host "$DB_HOST"
    bench set-mariadb-port "$DB_PORT"
    
    # Configure Redis
    bench set-redis-cache-host redis://localhost:6379
    bench set-redis-queue-host redis://localhost:6379
    bench set-redis-socketio-host redis://localhost:6379
    
    # Get LMS app
    echo "Getting LMS app..."
    bench get-app lms https://github.com/frappe/lms.git
    
else
    echo "Bench already exists, using existing setup"
    cd frappe-bench
fi

# Ensure site exists
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
    bench --site "$SITE_NAME" set-config server_script_enabled 1
    bench --site "$SITE_NAME" clear-cache
    
else
    echo "Site $SITE_NAME already exists"
fi

# Set the site as default
bench use "$SITE_NAME"

# Build assets for production
echo "Building assets for production..."
bench build --production

# Setup production configuration
echo "Setting up production configuration..."

# Create a simple Procfile for production
cat > Procfile << EOF
web: gunicorn -b 0.0.0.0:$PORT -w 4 --timeout 120 --preload frappe.app:application --max-requests 5000 --max-requests-jitter 500
worker: python -m frappe.utils.bench worker
schedule: python -m frappe.utils.bench schedule
socketio: node apps/frappe/socketio.js
EOF

# Create production site config
bench --site "$SITE_NAME" set-config maintenance_mode 0
bench --site "$SITE_NAME" set-config allow_tests 0

# Migrate if needed
echo "Running migrations..."
bench --site "$SITE_NAME" migrate

# Clear cache and build
bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache

echo "=== Starting Frappe LMS in Production Mode ==="

# Start the application using gunicorn for production
exec gunicorn \
    --bind 0.0.0.0:$PORT \
    --workers 4 \
    --worker-class sync \
    --worker-connections 1000 \
    --timeout 120 \
    --keepalive 5 \
    --max-requests 5000 \
    --max-requests-jitter 500 \
    --preload \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    frappe.app:application 