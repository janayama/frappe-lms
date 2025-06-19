#!/bin/bash
set -e

# This script runs as ROOT.

# Since we are root, we need to cd to the correct directory.
cd /home/frappe/frappe-bench

# Set a shell variable for the site name.
# It's crucial to export this so the `su` sub-shell can see it.
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
echo "$SITE_NAME" > sites/currentsite.txt

# This is a critical step to ensure the bench context is set.
bench use "$SITE_NAME"

# STEP 2: Fix all permissions.
# Give ownership of all created files to the 'frappe' user.
chown -R frappe:frappe /home/frappe/frappe-bench/sites

# --- DIAGNOSTICS AS ROOT ---
echo "--- [ROOT] Configuration complete. Verifying filesystem... ---"
ls -laR sites
echo "--- [ROOT] common_site_config.json ---"
cat sites/common_site_config.json
echo "--- [ROOT] currentsite.txt ---"
cat sites/currentsite.txt
echo "--- [ROOT] Verifying permissions from frappe user's perspective... ---"
su frappe -c "ls -laR /home/frappe/frappe-bench/sites"
echo "--- [ROOT] Switching to user 'frappe' to run application... ---"

# STEP 3: Switch to the 'frappe' user and execute the rest of the logic.
# We use `su` with a "here document" to pass the script block.
# The `-m` flag preserves the environment variables we exported.
su -m frappe <<'EOF'
set -e
cd /home/frappe/frappe-bench

# Check if the site is installed by checking its status.
# A failure here means the DB is not set up yet.
if ! bench --site "$SITE_NAME" status > /dev/null 2>&1; then
    echo "--- [frappe] Database not installed. Running first-time setup... ---"
    # A. Run migrate using our robust python script.
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
    # B. Set the admin password.
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    # C. Install the 'lms' app.
    bench --site "$SITE_NAME" install-app lms
else
    echo "--- [frappe] Database is already installed. Running migrations... ---"
    ./env/bin/python /usr/local/bin/run_migrate.py "$SITE_NAME"
fi

echo "--- [frappe] Starting Frappe server... ---"
bench start
EOF 