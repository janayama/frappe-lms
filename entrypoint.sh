#!/bin/bash
set -e

# This script runs as the 'frappe' user, as defined in the Dockerfile.
# The PATH is correctly set in the Dockerfile, so `bench` is available.
cd /home/frappe/frappe-bench

# Use SITE_NAME from env, default if not set.
SITE_NAME=${SITE_NAME:-"lms.localhost"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin"}
MARIADB_HOST=${MARIADB_HOST:-"mariadb"}
MARIADB_PORT=${MARIADB_PORT:-"3306"}
MARIADB_DATABASE=${MARIADB_DATABASE:-"frappe"}
MARIADB_USER=${MARIADB_USER:-"frappe"}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-"frappe"}
REDIS_URL=${REDIS_URL:-"redis://redis:6379"}

# Create the common site config if it doesn't exist
if [ ! -f "sites/common_site_config.json" ]; then
    echo "--- [frappe] Creating common_site_config.json ---"
    cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_port": $MARIADB_PORT,
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
}
EOF
fi

# Create the site
echo "--- [frappe] Creating site '$SITE_NAME'... ---"
bench new-site "$SITE_NAME" \
  --db-name "$MARIADB_DATABASE" \
  --db-user "$MARIADB_USER" \
  --db-password "$MARIADB_PASSWORD" \
  --admin-password "$ADMIN_PASSWORD" \
  --install-app lms \
  --force

# Set the default site for future bench commands.
bench use "$SITE_NAME"

echo "--- [frappe] Running migrations... ---"
bench --site "$SITE_NAME" migrate

echo "--- [frappe] Starting Frappe server... ---"
bench start 