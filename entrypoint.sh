#!/bin/bash
set -e

# This script runs as ROOT.
cd /home/frappe/frappe-bench

# Export these variables so the `su` sub-shell can see them.
export SITE_NAME=${SITE_NAME:-"lms.localhost"}
export ADMIN_PASSWORD=${ADMIN_PASSWORD}

# STEP 1: Manually create all config files and directories as root.
echo "--- [ROOT] Creating configuration files... ---"
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
    "db_user": "$MARIADB_USER",
    "db_type": "mariadb"
}
EOF

echo "$SITE_NAME" > sites/sites.txt

# STEP 2: Fix all permissions BEFORE switching user.
chown -R frappe:frappe /home/frappe/frappe-bench/sites

echo "--- [ROOT] Configuration complete. Switching to user 'frappe'... ---"

# STEP 3: Switch to the 'frappe' user and execute the rest of the logic.
# The `-c` flag runs the provided command string in a new shell.
# We activate the virtualenv and then run the standard bench commands.
su -m frappe -c "
set -e
cd /home/frappe/frappe-bench
source env/bin/activate

echo '--- [frappe] Bench environment activated. ---'

bench use '$SITE_NAME'

if ! bench --site '$SITE_NAME' status > /dev/null 2>&1; then
    echo '--- [frappe] Database not installed. Running first-time setup... ---'
    bench --site '$SITE_NAME' migrate
    bench --site '$SITE_NAME' set-admin-password '$ADMIN_PASSWORD'
    bench --site '$SITE_NAME' install-app lms
else
    echo '--- [frappe] Database is already installed. Running migrations... ---'
    bench --site '$SITE_NAME' migrate
fi

echo '--- [frappe] Starting Frappe server... ---'
bench start
" 