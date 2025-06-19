#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set the site name from the SITE_NAME environment variable provided by Railway
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# STEP 1: Always create the site's configuration.
# This ensures a fresh, correct config on every deploy, pointing to the Railway services.
mkdir -p sites/$SITE_NAME
cat <<EOF > sites/$SITE_NAME/site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_port": $MARIADB_PORT,
    "db_user": "$MARIADB_USER",
    "redis_cache": "$REDIS_URL",
    "redis_queue": "$REDIS_URL",
    "redis_socketio": "$REDIS_URL",
    "developer_mode": 1
}
EOF

# STEP 2: Register the site in sites.txt so the bench knows about it.
echo "$SITE_NAME" > sites/sites.txt

# STEP 3: Check if the site is installed by looking for a core Frappe table.
# This uses the 'mariadb' command, which is correct for this environment.
INSTALLED=$(echo "SHOW TABLES LIKE 'tabDocType';" | bench --site "$SITE_NAME" mariadb | grep 'tabDocType' || echo "")

# STEP 4: Run first-time installation or updates.
if [ -z "$INSTALLED" ]; then
    echo "Database for $SITE_NAME appears to be empty. Running first-time installation..."
    # A. Run migrate. On an empty DB, this creates the entire schema.
    bench --site "$SITE_NAME" migrate
    # B. Set the admin password non-interactively.
    bench --site "$SITE_NAME" set-admin-password "$ADMIN_PASSWORD"
    # C. Install the 'lms' app, which runs its own migrations.
    bench --site "$SITE_NAME" install-app lms
else
    echo "Database for $SITE_NAME is already installed. Running migrations for updates."
    # On subsequent deploys, just run migrate to apply any new changes.
    bench --site "$SITE_NAME" migrate
fi

echo "Starting Frappe server..."
bench start 