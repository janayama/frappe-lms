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

# 4. Manually create the global config BEFORE running new-site.
# This ensures new-site uses our settings for its first connection.
echo "Creating/updating global config (common_site_config.json)..."
python3 -c "
import json
import os
config_path = 'sites/common_site_config.json'
if os.path.exists(config_path):
    with open(config_path, 'r') as f:
        config = json.load(f)
else:
    config = {}

# Set global DB connection and health check settings
config['db_host'] = os.environ.get('MYSQLHOST')
config['db_port'] = int(os.environ.get('MYSQLPORT', 3306))
config['serve_default_site'] = True
# ** THE CRITICAL FIX **: Set SQL mode for the session.
config['db_init_commands'] = \"SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION'\"
# Set Redis config
config['redis_cache'] = 'redis://localhost:6379'
config['redis_queue'] = 'redis://localhost:6379'
config['redis_socketio'] = 'redis://localhost:6379'

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print('--- common_site_config.json contents ---')
with open(config_path, 'r') as f:
    print(f.read())
print('----------------------------------------')
print('Global config updated.')
"

# 5. Create and install site only if it's not already installed properly.
if ! bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
    echo "Site '$SITE_NAME' is not installed correctly. Starting full installation..."

    if [ ! -d "apps/lms" ]; then
        echo "Getting LMS app..."
        bench get-app lms
    fi
    
    # new-site will now read the global config we just created
    bench new-site "$SITE_NAME" \
        --db-type mariadb \
        --mariadb-root-username "$DB_USER" \
        --mariadb-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --force \
        --no-mariadb-socket

    echo "Installing LMS app on site..."
    bench --site "$SITE_NAME" install-app lms
    
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" clear-cache
    echo "Site '$SITE_NAME' created and installed successfully."
else
    echo "Site '$SITE_NAME' already installed. Skipping creation."
fi

# 6. Start the production server using gunicorn
echo "Starting Gunicorn production server on port $APP_PORT..."
exec ./env/bin/gunicorn \
    --bind="0.0.0.0:$APP_PORT" \
    --workers=2 \
    --threads=4 \
    --worker-class=gthread \
    --preload \
    frappe.app:application 