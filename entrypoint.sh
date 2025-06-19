#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set a shell variable for the site name.
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# STEP 1: Manually create all config files and directories.
cat <<EOF > sites/common_site_config.json
{
    "db_host": "$MARIADB_HOST",
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
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
    "db_user": "$MARIADB_USER"
}
EOF

# STEP 2: Register the site in sites.txt so the bench knows about it.
echo "$SITE_NAME" > sites/sites.txt

# STEP 3: Check if the site is installed using a direct Python command.
# The site name is directly injected into the script to avoid environment variable issues.
IS_INSTALLED_SCRIPT="import frappe; frappe.init('$SITE_NAME'); frappe.connect(); print('1' if frappe.db.table_exists('User') else '0'); frappe.db.close()"
INSTALLED=$(./env/bin/python -c "$IS_INSTALLED_SCRIPT")

# STEP 4: Run first-time installation or updates.
if [ "$INSTALLED" = "0" ]; then
    echo "Database for $SITE_NAME appears to be empty. Running first-time installation..."
    # A. Run migrate, passing the site name as an argument.
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
    # B. Set the admin password.
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    # C. Install the 'lms' app.
    bench --site "$SITE_NAME" install-app lms
else
    echo "Database for $SITE_NAME is already installed. Running migrations for updates."
    # On subsequent deploys, run migrate, passing the site name as an argument.
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
fi

echo "Starting Frappe server..."
bench start 