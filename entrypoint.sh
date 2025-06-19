#!/bin/bash
set -e

# This is the CRITICAL FIX:
# Explicitly set the PATH to prioritize the virtual environment's executables.
# This ensures we use the correct `bench` and `python` commands throughout the script.
export PATH="/home/frappe/frappe-bench/env/bin:$PATH"

# From this point on, all `bench` and `python` commands will use the correct environment.

cd /home/frappe/frappe-bench
export SITE_NAME=${SITE_NAME:-"lms.localhost"}

# STEP 1: Check if the site directory already exists.
# If it does, we assume it's already installed and just run migrations.
if [ -d "sites/$SITE_NAME" ]; then
    echo "--- [frappe] Site directory already exists. Running migrations... ---"
    bench --site "$SITE_NAME" migrate
    echo "--- [frappe] Starting Frappe server... ---"
    bench start
    exit 0
fi

# STEP 2: If the site does NOT exist, run the full first-time setup.
echo "--- [frappe] Site directory does not exist. Running first-time setup... ---"

# A. Use our `expect` script to run `bench new-site` non-interactively.
# This creates the site with a dummy local DB, but correctly sets up the filesystem.
/usr/local/bin/setup_site.exp "$SITE_NAME"

# B. IMMEDIATELY overwrite the dummy config with the real Railway DB and Redis config.
echo "--- [frappe] Overwriting dummy config with Railway config... ---"
cat <<EOF > "sites/$SITE_NAME/site_config.json"
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_port": $MARIADB_PORT,
    "db_user": "$MARIADB_USER",
    "db_type": "mariadb",
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL"
}
EOF

# C. Set the default site, which is also required.
bench config set-common-config -c default_site "$SITE_NAME"

# D. Now, run migrate. This will populate the REAL Railway database.
echo "--- [frappe] Populating the real database... ---"
bench --site "$SITE_NAME" migrate

# E. Set the admin password and install the lms app.
bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
bench --site "$SITE_NAME" install-app lms

echo "--- [frappe] First-time setup complete. Starting Frappe server... ---"
bench start 