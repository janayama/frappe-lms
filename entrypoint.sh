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

# --- Step 1: Configure Bench ---
# Create the common configuration file used by all sites managed by this bench.
# This file tells Frappe how to connect to the database and Redis.
echo "--- [Frappe Entrypoint] Writing common_site_config.json ---"
cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_port": $MARIADB_PORT,
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
}
EOF
echo "Common configuration written successfully."

# In addition to the common config, we must create the site-specific
# config file *before* calling `new-site`.
echo "--- [Frappe Entrypoint] Writing site_config.json for $SITE_NAME ---"
# Create site-specific directory
mkdir -p "sites/$SITE_NAME"
cat <<EOF > "sites/$SITE_NAME/site_config.json"
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_user": "$MARIADB_USER"
}
EOF
echo "Site-specific configuration written successfully."

# --- Step 2: Create and Install Site ---
# Now that the config files are in place, `bench new-site` will use them automatically.
# We no longer pass the --db-* flags. We only need to provide the site name,
# admin password, and the app to install.
# The `--force` flag makes this command idempotent.
echo "--- [Frappe Entrypoint] Creating site '$SITE_NAME' using pre-existing config... ---"
bench new-site "$SITE_NAME" \
  --admin-password "$ADMIN_PASSWORD" \
  --install-app lms \
  --force
echo "Site creation command executed."

# --- Step 3: Run Database Migrations ---
# After the site is created, we must run migrations to ensure the database
# schema is up-to-date with the latest version of the installed apps.
echo "--- [Frappe Entrypoint] Running database migrations... ---"
bench --site "$SITE_NAME" migrate
echo "Migrations completed."

# --- Step 4: Start the Application ---
# The `bench start` command reads the `Procfile` and starts all necessary
# processes, including the web server, scheduler, and background workers.
# While not a true production-grade process manager, it's the standard
# way to run Frappe and is suitable for getting started on Railway.
echo "--- [Frappe Entrypoint] Starting Frappe processes via 'bench start'... ---"
bench start 