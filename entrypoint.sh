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

# --- Step 1: Set Common Configuration ---
echo "--- [Frappe Entrypoint] Setting common configuration... ---"
# Set Redis configuration that applies to all sites
bench set-config redis_cache "$REDIS_URL"
bench set-config redis_queue "$REDIS_URL"
bench set-config redis_socketio "$REDIS_URL"

# --- Step 2: Create New Site ---
echo "--- [Frappe Entrypoint] Creating new site with existing database... ---"
bench new-site "$SITE_NAME" \
    --db-host "$MARIADB_HOST" \
    --db-port "$MARIADB_PORT" \
    --db-name "$MARIADB_DATABASE" \
    --db-user "$MARIADB_USER" \
    --db-password "$MARIADB_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --install-app lms \
    --no-mariadb-socket
echo "Site created successfully."

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