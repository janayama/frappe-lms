#!/bin/bash
set -e

# This script runs as ROOT.

# Since we are root, we need to cd to the correct directory.
cd /home/frappe/frappe-bench

# Export these variables so the `su` sub-shell can see them.
export SITE_NAME=${SITE_NAME:-"lms.localhost"}
export ADMIN_PASSWORD=${ADMIN_PASSWORD}

echo "--- [ROOT] Configuring site: $SITE_NAME ---"

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

# STEP 2: Fix all permissions BEFORE switching user.
chown -R frappe:frappe /home/frappe/frappe-bench/sites

echo "--- [ROOT] Configuration complete. Switching to user 'frappe'... ---"

# STEP 3: Switch to the 'frappe' user and execute the rest of the logic.
# We explicitly use `/bin/bash` to ensure the `source` command is available.
su -m frappe -s /bin/bash <<'EOF'
#!/bin/bash
set -e
cd /home/frappe/frappe-bench

# This is the CRITICAL FIX: Activate the virtual environment.
# This sets up the correct PATH and environment for all `bench` commands.
source ./env/bin/activate

# Set the active site for the bench context. This creates currentsite.txt.
bench use "$SITE_NAME"

# Check if the site is installed by checking its status.
if ! bench --site "$SITE_NAME" status > /dev/null 2>&1; then
    echo "--- [frappe] Database not installed. Running first-time setup... ---"
    python /usr/local/bin/run_migrate.py "$SITE_NAME"
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    bench --site "$SITE_NAME" install-app lms
else
    echo "--- [frappe] Database is already installed. Running migrations... ---"
    python /usr/local/bin/run_migrate.py "$SITE_NAME"
fi

echo "--- [frappe] Starting Frappe server... ---"
bench start
EOF 