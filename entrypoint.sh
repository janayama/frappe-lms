#!/bin/bash
set -e

# This script runs as ROOT.

# Since we are root, we need to cd to the correct directory.
cd /home/frappe/frappe-bench

# Set a shell variable for the site name.
# It's crucial to export this so the `su-exec` sub-shell can see it.
export SITE_NAME=${SITE_NAME:-"lms.localhost"}
export ADMIN_PASSWORD=${ADMIN_PASSWORD}

echo "--- Running as user: $(whoami) ---"
echo "--- Configuring site: $SITE_NAME ---"

# STEP 1: Manually create all config files and directories as root.
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
    "db_user": "$MARIADB_USER"
}
EOF

echo "$SITE_NAME" > sites/sites.txt
echo "$SITE_NAME" > sites/currentsite.txt

# STEP 2: Fix all permissions.
# Give ownership of all created files to the 'frappe' user.
chown -R frappe:frappe /home/frappe/frappe-bench/sites

echo "--- Configuration complete. Site directory contents: ---"
ls -laR sites
echo "--- Switching to user 'frappe' to run application... ---"

# STEP 3: Switch to the 'frappe' user and execute the rest of the logic.
# `su-exec` is a lightweight tool to run a command as a different user.
# We pass a new script block to it.
su-exec frappe:frappe bash <<'EOF'
set -e
cd /home/frappe/frappe-bench

# STEP 3a: Check if the site is installed using a direct Python command.
IS_INSTALLED_SCRIPT="import frappe; frappe.init('$SITE_NAME'); frappe.connect(); print('1' if frappe.db.table_exists('User') else '0'); frappe.db.close()"
INSTALLED=$(./env/bin/python -c "$IS_INSTALLED_SCRIPT")

# STEP 3b: Run first-time installation or updates.
if [ "$INSTALLED" = "0" ]; then
    echo "--- (as frappe) Database is empty. Running first-time installation... ---"
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    bench --site "$SITE_NAME" install-app lms
else
    echo "--- (as frappe) Database is already installed. Running migrations... ---"
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
fi

echo "--- (as frappe) Starting Frappe server... ---"
bench start
EOF 