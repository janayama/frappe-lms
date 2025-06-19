#!/bin/bash
set -e

# This is the CRITICAL FIX:
# Explicitly set the PATH to prioritize the virtual environment's executables.
# This ensures we use the correct `bench` and `python` commands throughout the script.
export PATH="/home/frappe/frappe-bench/env/bin:$PATH"

# From this point on, all `bench` and `python` commands will use the correct environment.

cd /home/frappe/frappe-bench
export SITE_NAME=${SITE_NAME:-"lms.localhost"}

# Manually create all config files and directories.
# Since the entrypoint now runs as `frappe`, we don't need root or chown.
# The user already has permission to write to its own home directory.
echo "--- [frappe] Configuring site: $SITE_NAME ---"

cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL",
    "default_site": "$SITE_NAME"
}
EOF

mkdir -p "sites/$SITE_NAME/logs"
touch "sites/$SITE_NAME/logs/database.log"
touch "sites/$SITE_NAME/logs/frappe.log"

cat <<EOF > "sites/$SITE_NAME/site_config.json"
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_port": $MARIADB_PORT,
    "db_user": "$MARIADB_USER",
    "db_type": "mariadb"
}
EOF

echo "$SITE_NAME" > sites/sites.txt
bench use "$SITE_NAME"

# --- DIAGNOSTICS ---
echo "--- [frappe] Verifying configuration ---"
echo "--- common_site_config.json:"
cat sites/common_site_config.json
echo "--- $SITE_NAME/site_config.json:"
cat "sites/$SITE_NAME/site_config.json"
echo "---"

# Check if the site is installed by checking its status.
if ! bench --site "$SITE_NAME" status > /dev/null 2>&1; then
    echo "--- [frappe] Database not installed. Running first-time setup... ---"
    # Use the standard migrate command. This creates the schema and runs app migrations.
    bench --site "$SITE_NAME" migrate
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    bench --site "$SITE_NAME" install-app lms
else
    echo "--- [frappe] Database is already installed. Running migrations... ---"
    # For subsequent deploys, just run migrate.
    bench --site "$SITE_NAME" migrate
fi

echo "--- [frappe] Starting Frappe server... ---"
bench start 