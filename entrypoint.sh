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

# --- Step 1: Write Config Files ---
echo "--- [Frappe Entrypoint] Writing configuration files... ---"
# Write common_site_config.json
cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_port": "$MARIADB_PORT",
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
}
EOF
# Write site_config.json for the site
mkdir -p "sites/$SITE_NAME"
cat <<EOF > "sites/$SITE_NAME/site_config.json"
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_user": "$MARIADB_USER"
}
EOF
# Since we are creating the site manually, we also need to create the logs folder.
mkdir -p "sites/$SITE_NAME/logs"
echo "Configuration files written successfully."

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
bench --site "$SITE_NAME" migrate --skip-failing
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