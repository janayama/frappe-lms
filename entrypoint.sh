#!/bin/bash
set -e

# This script runs as the 'frappe' user, as defined in the Dockerfile.
# The PATH is correctly set in the Dockerfile, so `bench` is available.
cd /home/frappe/frappe-bench

# Use SITE_NAME from env, default if not set.
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# If the site directory doesn't exist, this is a first-time run.
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "--- [frappe] Site '$SITE_NAME' not found. Running first-time setup... ---"

    # 1. Create site config files with credentials from environment variables.
    cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_port": $MARIADB_PORT,
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
}
EOF

    # Create the site directory BEFORE writing the site-specific config.
    mkdir -p "sites/$SITE_NAME"

    cat <<EOF > "sites/$SITE_NAME/site_config.json"
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_user": "$MARIADB_USER"
}
EOF

    # 2. Use `bench reinstall` for a robust, idempotent setup.
    # It creates the DB schema and sets the admin password.
    # --skip-service-check is CRITICAL for containerized environments.
    bench --site "$SITE_NAME" reinstall --yes --admin-password "$ADMIN_PASSWORD" --skip-service-check
    bench --site "$SITE_NAME" install-app lms
    # Set the default site for future bench commands.
    bench use "$SITE_NAME"

    echo "--- [frappe] First-time setup complete. ---"
else
    echo "--- [frappe] Site '$SITE_NAME' found. Running migrations... ---"
    # For subsequent starts, just run migrations.
    # --skip-service-check is CRITICAL for containerized environments.
    bench --site "$SITE_NAME" migrate --skip-service-check
fi

echo "--- [frappe] Starting Frappe server... ---"
bench start 