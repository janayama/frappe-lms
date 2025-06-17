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
echo "Database User: $DB_USER"
echo "Port: $PORT"
echo ""
echo "=== Environment Variable Debug ==="
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "MYSQLUSER: $MYSQLUSER"
echo "MYSQLPASSWORD: [${#MYSQLPASSWORD} characters]"
echo "SITE_NAME: $SITE_NAME"
echo "ADMIN_PASSWORD: [${#ADMIN_PASSWORD} characters]"
echo ""

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

# Install Frappe framework
echo "Installing Frappe framework..."
if [ ! -d "apps/frappe" ]; then
    echo "Cloning Frappe framework..."
    git clone https://github.com/frappe/frappe.git apps/frappe --depth 1 --branch version-15
fi

# Install LMS app
echo "Installing LMS app..."
if [ ! -d "apps/lms" ]; then
    echo "Cloning LMS app..."
    git clone https://github.com/frappe/lms.git apps/lms --depth 1
fi

# Create virtual environment and install dependencies
echo "Setting up Python environment..."
echo "Current directory: $(pwd)"
echo "Python version: $(python3 --version)"
echo "Available disk space:"
df -h .

# Skip virtual environment for now and use system Python
echo "Using system Python (skipping virtual environment for Railway compatibility)"

# Install Frappe and LMS dependencies using system Python
echo "Installing Frappe and LMS dependencies..."
pip3 install --user --upgrade pip

# Clean up any existing conflicting packages
echo "Cleaning up existing packages to avoid conflicts..."
pip3 uninstall -y cairocffi lxml markdown fuzzywuzzy websocket_client razorpay 2>/dev/null || echo "No conflicting packages to remove"

# Create a temporary requirements file with exact versions to avoid conflicts
echo "Creating requirements file with compatible versions..."
cat > /tmp/requirements.txt << 'EOF'
# Core Frappe dependencies with exact versions
cairocffi==1.5.1
lxml==4.9.4
markdown==3.5.2
fuzzywuzzy==0.18.0
websocket_client==1.6.4
razorpay==1.4.2

# Install frappe first
-e apps/frappe

# Then install LMS with --no-deps to avoid conflicts
EOF

# Install using the requirements file
echo "Installing packages with controlled dependencies..."
pip3 install --user -r /tmp/requirements.txt

# Install LMS separately with --no-deps to prevent it from overriding dependencies
echo "Installing LMS application without dependency resolution..."
pip3 install --user --no-deps -e apps/lms

# Verify the installation
echo "Verifying installation..."
python3 -c "import frappe; print(f'Frappe version: {frappe.__version__}')" || echo "Frappe import failed"
python3 -c "import lms; print('LMS imported successfully')" || echo "LMS import failed"

# Ensure user bin directory is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Create apps.txt to tell Frappe which apps are available
echo "frappe" > sites/apps.txt
echo "lms" >> sites/apps.txt

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
  "redis_socketio": "redis://localhost:6379/2",
  "installed_apps": ["frappe", "lms"]
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
    
    # Export environment variables for the Python script
    export DB_HOST="$DB_HOST"
    export DB_PORT="$DB_PORT"
    export DB_NAME="$DB_NAME"
    export DB_USER="$DB_USER"
    export DB_PASSWORD="$DB_PASSWORD"
    export SITE_NAME="$SITE_NAME"
    export ADMIN_PASSWORD="$ADMIN_PASSWORD"
    
    # Initialize Frappe database structure
    echo "Running Frappe initialization..."
    echo "Using database: $DB_HOST:$DB_PORT/$DB_NAME"
    echo "Exported variables for Python script:"
    echo "  DB_HOST=$DB_HOST"
    echo "  DB_PORT=$DB_PORT"
    echo "  DB_NAME=$DB_NAME"
    echo "  DB_USER=$DB_USER"
    echo "  DB_PASSWORD=[${#DB_PASSWORD} characters]"
    if [ -f "./init_frappe.py" ]; then
        python3 ./init_frappe.py
    fi
    
    echo "Database initialization completed"
    
    # Create the Frappe site properly
    echo "Creating Frappe site..."
    cd /home/frappe/frappe-lms-*/
    export PATH="$HOME/.local/bin:$PATH"
    
    # Check if site already exists in Frappe
    if ! python3 -c "import frappe; frappe.init(site='$SITE_NAME'); print('Site exists')" 2>/dev/null; then
        echo "Site not found in Frappe, creating it..."
        
        # Create the site using Frappe's site creation
        python3 -c "
import frappe
import os

# Set environment
os.chdir('$(pwd)')
frappe.init()

# Create the site
try:
    from frappe.installer import make_site_dirs
    from frappe.utils import get_site_config
    
    site_name = '$SITE_NAME'
    print(f'Creating site: {site_name}')
    
    # Make sure site directories exist
    make_site_dirs(site_name)
    
    # Create basic site config if it doesn't exist
    site_config_path = f'sites/{site_name}/site_config.json'
    if not os.path.exists(site_config_path):
        import json
        config = {
            'db_name': '$DB_NAME',
            'db_password': '$DB_PASSWORD',
            'db_type': 'mysql',
            'db_host': '$DB_HOST',
            'db_port': $DB_PORT,
            'installed_apps': ['frappe', 'lms']
        }
        with open(site_config_path, 'w') as f:
            json.dump(config, f, indent=2)
    
    print(f'Site {site_name} created successfully')
    
except Exception as e:
    print(f'Error creating site: {e}')
    print('Continuing with existing setup...')
"
    else
        echo "Site already exists in Frappe"
    fi
    
else
    echo "Warning: Database connection failed, but continuing..."
fi

echo "=== Starting Frappe LMS Production Server ==="

# Use system Python and ensure PATH includes user bin directory
export PATH="$HOME/.local/bin:$PATH"
echo "Using system Python with user packages"

# Set PYTHONPATH to include the current directory and apps
export PYTHONPATH="$(pwd):$(pwd)/apps:$PYTHONPATH"

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