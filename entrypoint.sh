#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set a shell variable for the site name.
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# --- DIAGNOSTICS: Print current state ---
echo "--- Preparing to configure site: $SITE_NAME ---"
echo "Current working directory: $(pwd)"

# STEP 1: Manually create all config files and directories.
# The "default_site" key is the critical fix for the IncorrectSitePath error.
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
    "db_user": "$USER"
}
EOF

# STEP 2: Register the site in sites.txt so the bench knows about it.
echo "$SITE_NAME" > sites/sites.txt
# This is the final, critical step. The currentsite.txt file explicitly
# tells the framework which site is active, resolving the IncorrectSitePath error.
echo "$SITE_NAME" > sites/currentsite.txt

# --- DIAGNOSTICS: Print file system state after creation ---
echo "--- Configuration files created. Verifying contents... ---"
echo "Listing sites directory contents:"
ls -laR sites
echo "---"
echo "Contents of sites.txt:"
cat sites/sites.txt
echo "---"
echo "Contents of common_site_config.json:"
cat sites/common_site_config.json
echo "---"
echo "Contents of currentsite.txt:"
cat sites/currentsite.txt
echo "---"
echo "Contents of $SITE_NAME/site_config.json:"
cat "sites/$SITE_NAME/site_config.json"
echo "---"

# STEP 3: Check if the site is installed using a direct Python command.
echo "--- Checking if database is installed... ---"
IS_INSTALLED_SCRIPT="import frappe; frappe.init('$SITE_NAME'); frappe.connect(); print('1' if frappe.db.table_exists('User') else '0'); frappe.db.close()"
INSTALLED=$(./env/bin/python -c "$IS_INSTALLED_SCRIPT")

# STEP 4: Run first-time installation or updates.
if [ "$INSTALLED" = "0" ]; then
    echo "--- Database is empty. Running first-time installation... ---"
    # A. Run migrate, passing the site name as an argument.
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
    # B. Set the admin password.
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    # C. Install the 'lms' app.
    bench --site "$SITE_NAME" install-app lms
else
    echo "--- Database is already installed. Running migrations... ---"
    # On subsequent deploys, run migrate, passing the site name as an argument.
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
fi

echo "--- Starting Frappe server... ---"
bench start 