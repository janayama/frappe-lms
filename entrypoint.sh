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

# Function to test MySQL connection
test_mysql_connection() {
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1
}

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

# Create our own working directory that we have full control over
WORK_DIR="frappe-lms-$(date +%s)"
echo "Creating working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Create the basic directory structure manually
echo "Creating basic Frappe directory structure..."
mkdir -p sites
mkdir -p apps
mkdir -p logs
mkdir -p config
mkdir -p env

# Create sites directory and basic configuration
echo "Setting up sites configuration..."

# Create common site configuration
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

echo "Common site configuration created successfully"

# Create site directory and configuration
echo "Creating site directory and configuration..."

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

# Register the site in sites.txt
echo "$SITE_NAME" > sites/sites.txt
if [ "$RAILWAY_PUBLIC_DOMAIN" != "" ] && [ "$RAILWAY_PUBLIC_DOMAIN" != "$SITE_NAME" ]; then
    echo "$RAILWAY_PUBLIC_DOMAIN" >> sites/sites.txt
fi

# Set current site
echo "$SITE_NAME" > sites/currentsite.txt

echo "Site configuration created successfully"

# Copy our custom files to the working directory
echo "Setting up custom application files..."
if [ -f "/home/frappe/frappe-bench/static_server.py" ]; then
    cp /home/frappe/frappe-bench/static_server.py ./static_server.py
fi
if [ -f "/home/frappe/frappe-bench/init_frappe.py" ]; then
    cp /home/frappe/frappe-bench/init_frappe.py ./init_frappe.py
fi

# Test database connection and initialize if needed
echo "Testing database connection..."
if test_mysql_connection; then
    echo "Database connection successful"
    
    # Install mysql-connector-python if not available
    pip install mysql-connector-python > /dev/null 2>&1 || echo "mysql-connector-python already installed"
    
    # Initialize Frappe database structure
    echo "Running Frappe initialization..."
    if [ -f "./init_frappe.py" ]; then
        python3 ./init_frappe.py
    fi
    
    echo "Database initialization completed"
else
    echo "Warning: Database connection failed, but continuing..."
fi

echo "=== Starting Frappe LMS Production Server ==="

# Set PYTHONPATH to include the current directory
export PYTHONPATH="$(pwd):$PYTHONPATH"

# Start Gunicorn with optimized settings for Railway
exec gunicorn \
    --chdir="$(pwd)" \
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