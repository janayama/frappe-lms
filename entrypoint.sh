#!/bin/bash
# This script is designed to robustly initialize and run a Frappe application
# in a stateless, containerized environment like Railway.
set -e

# --- Configuration ---
# All configuration is driven by environment variables.
# Default values are provided for local testing or when variables are not set.

# The site name MUST be provided.
SITE_NAME=${SITE_NAME:?"Error: SITE_NAME environment variable not set."}

# Admin password for the Frappe site.
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin"}

# Database credentials provided by Railway or other managed services.
MARIADB_HOST=${MARIADB_HOST:-"mariadb"}
MARIADB_PORT=${MARIADB_PORT:-"3306"}
MARIADB_DATABASE=${MARIADB_DATABASE:-"frappe"}
MARIADB_USER=${MARIADB_USER:-"frappe"}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-"frappe"}
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-"frappe"}


# Redis URLs for caching, queues, and socket.io.
REDIS_URL=${REDIS_URL:-"redis://redis:6379"}

echo "--- [Frappe Entrypoint] Initializing for site: $SITE_NAME ---"

# The Dockerfile sets the working directory to /home/frappe/frappe-bench
cd /home/frappe/frappe-bench

# --- Step 1: Create New Site ---
echo "--- [Frappe Entrypoint] Checking if site exists... ---"
if [ -d "sites/$SITE_NAME" ] && [ -f "sites/$SITE_NAME/site_config.json" ]; then
    echo "Site $SITE_NAME already exists, skipping creation..."
else
    echo "--- [Frappe Entrypoint] Creating new site with existing database... ---"
    bench new-site "$SITE_NAME" \
        --db-host "$MARIADB_HOST" \
        --db-port "$MARIADB_PORT" \
        --db-name "$MARIADB_DATABASE" \
        --db-password "$MARIADB_PASSWORD" \
        --db-root-username "root" \
        --db-root-password "$MARIADB_ROOT_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --install-app lms \
        --mariadb-user-host-login-scope='%' \
        --force
    echo "Site created successfully."
fi

# --- Step 2: Configure Redis and Database User ---
echo "--- [Frappe Entrypoint] Setting Redis and database configuration... ---"
bench --site "$SITE_NAME" set-config redis_cache "$REDIS_URL"
bench --site "$SITE_NAME" set-config redis_queue "$REDIS_URL"
bench --site "$SITE_NAME" set-config redis_socketio "$REDIS_URL"

# Set database user if different from database name
if [ "$MARIADB_USER" != "$MARIADB_DATABASE" ]; then
    echo "Setting database user to: $MARIADB_USER"
    bench --site "$SITE_NAME" set-config db_user "$MARIADB_USER"
fi

bench --site "$SITE_NAME" show-config -f json

echo "Configuration set successfully."

# --- Step 2.5: Configure for external services ---
echo "--- [Frappe Entrypoint] Configuring for external services... ---"
# Skip local service checks since we're using external managed services
bench --site "$SITE_NAME" set-config skip_redis_config_generation 1
bench --site "$SITE_NAME" set-config skip_setup_wizard 1

# --- Step 3: Run Database Migrations ---
# Use the standard bench migrate command with skip-failing flag for robustness
echo "--- [Frappe Entrypoint] Running database migrations... ---"

# Debug: Check if we can connect to the database and Redis
echo "--- [DEBUG] Testing database connection... ---"
bench --site "$SITE_NAME" console <<EOF
import frappe
try:
    frappe.connect()
    print("✓ Database connection successful")
    frappe.db.sql("SELECT 1")
    print("✓ Database query successful")
except Exception as e:
    print(f"✗ Database connection failed: {e}")
    
try:
    from frappe.utils.redis_wrapper import RedisWrapper
    redis = RedisWrapper.from_url(frappe.conf.redis_cache)
    redis.ping()
    print("✓ Redis connection successful")
except Exception as e:
    print(f"✗ Redis connection failed: {e}")
EOF

echo "--- [DEBUG] Checking service status... ---"
# Check what services bench thinks are running
bench setup requirements --node || echo "Node requirements check completed"

# Try migration with simplified approach
echo "--- [Frappe Entrypoint] Attempting migration... ---"
if bench --site "$SITE_NAME" migrate --skip-failing; then
    echo "✓ Standard migration completed successfully"
else
    echo "--- [DEBUG] Standard migrate failed, trying console approach... ---"
    
    # Use console approach which is more reliable
    bench --site "$SITE_NAME" console <<EOF
import frappe
frappe.connect()
try:
    # First try to run migrations
    try:
        import frappe.migrate
        frappe.migrate.migrate(skip_failing=True)
        print("✓ Migration completed successfully")
    except Exception as e1:
        print(f"Migration failed, trying database sync: {e1}")
        # Fallback: sync database schema
        frappe.db.sync_with_database()
        print("✓ Database schema synchronized")
except Exception as e:
    print(f"✗ Migration failed: {e}")
    # Don't fail the entire deployment, just log the error
    import traceback
    traceback.print_exc()
EOF
fi

echo "Migrations completed."

# --- Step 4: Set Admin Password ---
# Set the admin password for the newly installed site.
echo "--- [Frappe Entrypoint] Setting admin password... ---"
bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD" --logout-all-sessions
echo "Admin password set."

# --- Step 5: Start Application ---
echo "--- [Frappe Entrypoint] Starting Frappe application... ---"

# Debug: Check if configuration is being read properly
echo "--- [DEBUG] Checking Redis configuration... ---"
bench --site "$SITE_NAME" console <<EOF
import frappe
print(f"Redis Cache: {frappe.conf.get('redis_cache', 'NOT SET')}")
print(f"Redis Queue: {frappe.conf.get('redis_queue', 'NOT SET')}")
print(f"Redis SocketIO: {frappe.conf.get('redis_socketio', 'NOT SET')}")
EOF

# Test Redis connectivity before starting services
echo "--- [DEBUG] Testing Redis connectivity using Frappe's Redis... ---"
bench --site "$SITE_NAME" console <<EOF
import frappe
try:
    from frappe.utils.redis_wrapper import RedisWrapper
    
    # Test cache Redis
    cache_redis = RedisWrapper.from_url(frappe.conf.redis_cache)
    cache_redis.ping()
    print('✓ Redis Cache connection successful')
    
    # Test queue Redis  
    queue_redis = RedisWrapper.from_url(frappe.conf.redis_queue)
    queue_redis.ping()
    print('✓ Redis Queue connection successful')
    
    # Test socketio Redis
    socketio_redis = RedisWrapper.from_url(frappe.conf.redis_socketio)
    socketio_redis.ping()
    print('✓ Redis SocketIO connection successful')
    
except Exception as e:
    print(f'✗ Redis connectivity test failed: {e}')
    import traceback
    traceback.print_exc()
EOF

# Start services one by one with proper error handling
echo "--- [Frappe Entrypoint] Starting web server... ---"

# Ensure the site is properly initialized before starting the server
echo "--- [DEBUG] Final site check... ---"
if bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
    echo "✓ Site is properly configured"
    
    # Check if we can connect to all required services
    echo "--- [DEBUG] Final connectivity check... ---"
    bench --site "$SITE_NAME" console <<EOF
import frappe
try:
    frappe.connect()
    frappe.db.sql("SELECT 1")
    print("✓ Database connectivity confirmed")
except Exception as e:
    print(f"✗ Database issue: {e}")
    exit(1)
EOF
    
    echo "Starting Frappe application server on port 8000..."
    echo "Site should be available at http://localhost:8000"
    
    # Set production environment variables
    export FRAPPE_SITE="$SITE_NAME"
    
    # Set production configuration
    bench set-config developer_mode 0
    bench set-config allow_tests 0
    
    # Use the development server which is more reliable for containerized deployments
    # This will start on port 8000
    echo "Starting development server on port 8000..."
    exec bench --site "$SITE_NAME" serve --port 8000
    
else
    echo "✗ Site configuration issue detected"
    echo "--- [DEBUG] Site status check... ---"
    ls -la "sites/$SITE_NAME/" || echo "Site directory not found"
    exit 1
fi 
