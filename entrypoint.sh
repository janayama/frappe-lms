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

# Redis URLs for caching, queues, and socket.io.
REDIS_URL=${REDIS_URL:-"redis://redis:6379"}

echo "--- [Frappe Entrypoint] Initializing for site: $SITE_NAME ---"

# The Dockerfile sets the working directory to /home/frappe/frappe-bench
cd /home/frappe/frappe-bench

# --- Step 1: Set Configuration ---
echo "--- [Frappe Entrypoint] Setting site configuration... ---"
# Set common configuration using bench set-config
bench set-config db_host "$MARIADB_HOST"
bench set-config db_port "$MARIADB_PORT"
bench set-config redis_cache "$REDIS_URL"
bench set-config redis_queue "$REDIS_URL"
bench set-config redis_socketio "$REDIS_URL"

# Create site directory and set site-specific configuration
mkdir -p "sites/$SITE_NAME/logs"
bench --site "$SITE_NAME" set-config db_name "$MARIADB_DATABASE"
bench --site "$SITE_NAME" set-config db_password "$MARIADB_PASSWORD"
bench --site "$SITE_NAME" set-config db_user "$MARIADB_USER"
echo "Configuration set successfully."

bench --site all show-config -f json
# --- Step 2: Manually "Install" Site ---
# We bypass `new-site` which requires `CREATE USER` privileges.
# We create a dummy installed.json and then let `migrate` create the schema.
echo "--- [Frappe Entrypoint] Bypassing new-site; preparing for manual migration... ---"
if [ ! -f "sites/$SITE_NAME/installed.json" ]; then
    echo '["frappe", "lms"]' > "sites/$SITE_NAME/installed.json"
    echo "Created dummy installed.json to trick bench."
fi

# --- Step 3: Run Database Migrations ---
# Use the standard bench migrate command with skip-failing flag for robustness
echo "--- [Frappe Entrypoint] Running database migrations... ---"

bench --site "$SITE_NAME" migrate
echo "Migrations completed."

# --- Step 4: Set Admin Password ---
# Set the admin password for the newly installed site.
echo "--- [Frappe Entrypoint] Setting admin password... ---"
bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD" --logout-all-sessions
echo "Admin password set."

# --- Step 5: Start Application ---
# Start the Frappe processes using the Procfile.
echo "--- [Frappe Entrypoint] Starting Frappe processes via 'bench start'... ---"
bench start 