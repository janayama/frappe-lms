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

echo "=== Frappe LMS Railway Production Setup ==="
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
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: $service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Wait for database
wait_for_service "Database" \
    "mysql -h\"$DB_HOST\" -P\"$DB_PORT\" -u\"$DB_USER\" -p\"$DB_PASSWORD\" -e \"SELECT 1\"" \
    30

# Start Redis in the background (Railway single-process pattern)
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
    
    # Configure common site settings
    cat > sites/common_site_config.json << EOF
{
  "redis_cache": "redis://localhost:6379/0",
  "redis_queue": "redis://localhost:6379/1",
  "redis_socketio": "redis://localhost:6379/2",
  "database_name": "$DB_NAME",
  "root_login": "$DB_USER",
  "root_password": "$DB_PASSWORD",
  "host_name": "$DB_HOST",
  "db_port": $DB_PORT,
  "serve_default_site": true,
  "default_site": "$SITE_NAME",
  "auto_update": true,
  "developer_mode": 0,
  "maintenance_mode": 0,
  "allow_tests": false,
  "logging": 1
}
EOF
    
    # Get LMS app
    echo "Getting LMS app..."
    bench get-app lms https://github.com/frappe/lms.git
    
else
    echo "Bench already exists, using existing setup"
    cd frappe-bench
    
    # Ensure Redis configuration is up to date
    echo "Updating Redis configuration..."
    cat > sites/common_site_config.json << EOF
{
  "redis_cache": "redis://localhost:6379/0",
  "redis_queue": "redis://localhost:6379/1",
  "redis_socketio": "redis://localhost:6379/2",
  "database_name": "$DB_NAME",
  "root_login": "$DB_USER",
  "root_password": "$DB_PASSWORD",
  "host_name": "$DB_HOST",
  "db_port": $DB_PORT,
  "serve_default_site": true,
  "default_site": "$SITE_NAME",
  "auto_update": true,
  "developer_mode": 0,
  "maintenance_mode": 0,
  "allow_tests": false,
  "logging": 1
}
EOF
fi

# Ensure site exists
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating site directory and configuration manually..."
    
    # Create site directory structure
    mkdir -p "sites/$SITE_NAME"
    mkdir -p "sites/$SITE_NAME/private"
    mkdir -p "sites/$SITE_NAME/public"
    mkdir -p "sites/$SITE_NAME/locks"
    
    # Create a simple health check file
    echo '{"status": "ok", "message": "Frappe LMS is running"}' > "sites/$SITE_NAME/public/health"
    
    # Create a basic index.html for immediate health checks
    cat > "sites/$SITE_NAME/public/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Frappe LMS</title>
</head>
<body>
    <h1>Frappe LMS is starting...</h1>
    <p>The application is initializing. Please wait a moment.</p>
</body>
</html>
EOF
    
    # Create site_config.json with database connection
    cat > "sites/$SITE_NAME/site_config.json" << EOF
{
  "db_name": "$DB_NAME",
  "db_password": "$DB_PASSWORD",
  "db_type": "mysql",
  "db_host": "$DB_HOST",
  "db_port": $DB_PORT,
  "auto_update": true,
  "serve_default_site": true,
  "host_name": "$SITE_NAME",
  "developer_mode": 0,
  "admin_password": "$ADMIN_PASSWORD",
  "encryption_key": "$(openssl rand -base64 32)",
  "redis_cache": "redis://localhost:6379/0",
  "redis_queue": "redis://localhost:6379/1",
  "redis_socketio": "redis://localhost:6379/2"
}
EOF
    
    # Register the site in sites.txt (add Railway domain if different)
    echo "$SITE_NAME" > sites/sites.txt
    if [ "$RAILWAY_PUBLIC_DOMAIN" != "" ] && [ "$RAILWAY_PUBLIC_DOMAIN" != "$SITE_NAME" ]; then
        echo "$RAILWAY_PUBLIC_DOMAIN" >> sites/sites.txt
    fi
    
    # Set current site
    echo "$SITE_NAME" > sites/currentsite.txt
    
    # Create a basic database connection test
    echo "Testing database connection..."
    if test_mysql_connection; then
        echo "Database connection successful"
        
        # Install mysql-connector-python if not available
        pip install mysql-connector-python > /dev/null 2>&1 || echo "mysql-connector-python already installed"
        
        # Initialize Frappe database structure
        echo "Running Frappe initialization..."
        python3 /home/frappe/frappe-bench/init_frappe.py
        
        echo "Site configuration created successfully"
        echo "Frappe will initialize remaining components on first request"
    else
        echo "Warning: Database connection failed, but continuing..."
    fi
    
else
    echo "Site $SITE_NAME already exists"
    
    # Ensure the site is properly registered
    echo "$SITE_NAME" > sites/sites.txt
    echo "$SITE_NAME" > sites/currentsite.txt
    
    # Update the site config to include host_name if missing
    if [ -f "sites/$SITE_NAME/site_config.json" ]; then
        # Check if host_name is missing and add it
        if ! grep -q "host_name" "sites/$SITE_NAME/site_config.json"; then
            # Add host_name to existing config
            sed -i '$ s/}/,\n "host_name": "https:\/\/'$SITE_NAME'"\n}/' "sites/$SITE_NAME/site_config.json"
        fi
    fi
fi

# Set the site as default
bench use "$SITE_NAME"

# Build assets for production (this is safe and necessary)
echo "Building assets for production..."
bench build --production

# Run migrations if needed (skip for new sites, Frappe will auto-migrate)
echo "Checking if migrations are needed..."
if [ -f "sites/$SITE_NAME/locks/maintenance_mode.lock" ]; then
    echo "Site in maintenance mode, running migrations..."
    # Only run migrations if site is in maintenance mode
    bench --site "$SITE_NAME" --force migrate
else
    echo "Skipping migrations - Frappe will auto-migrate on startup"
fi

echo "=== Starting Frappe LMS Production Server ==="

# Set PYTHONPATH to include the current directory
export PYTHONPATH="/home/frappe/frappe-bench:$PYTHONPATH"

# Start Gunicorn with optimized settings for Railway
exec /home/frappe/frappe-bench/env/bin/gunicorn \
    --chdir=/home/frappe/frappe-bench \
    --bind=0.0.0.0:8080 \
    --workers=2 \
    --worker-class=sync \
    --worker-connections=1000 \
    --max-requests=1000 \
    --max-requests-jitter=50 \
    --preload \
    --timeout=120 \
    --keep-alive=2 \
    --log-level=info \
    --access-logfile=- \
    --error-logfile=- \
    static_server:application

# Function to test MySQL connection
test_mysql_connection() {
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1
} 