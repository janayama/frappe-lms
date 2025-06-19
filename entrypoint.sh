#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set the site name from the SITE_NAME environment variable provided by Railway
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# STEP 1: Configure the global bench settings to point to the remote services.
# This is the most reliable way to ensure all commands know where to connect.
bench config set-db-host "$MARIADB_HOST"
bench config set-redis-cache "$REDIS_URL"
bench config set-redis-queue "$REDIS_URL"
bench config set-redis-socketio "$REDIS_URL"

# STEP 2: Always create the site's required directory structure.
# This prevents FileNotFoundError for logs.
mkdir -p sites/$SITE_NAME/logs
touch sites/$SITE_NAME/logs/database.log
touch sites/$SITE_NAME/logs/frappe.log

# STEP 3: Create the site-specific config with the remaining details.
cat <<EOF > sites/$SITE_NAME/site_config.json
{
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_port": $MARIADB_PORT,
    "db_user": "$MARIADB_USER"
}
EOF

# STEP 4: Register the site in sites.txt so the bench knows about it.
echo "$SITE_NAME" > sites/sites.txt

# STEP 5: Check if the site is installed by looking for a core Frappe table.
# This uses the 'mariadb' command, which is correct for this environment.
INSTALLED=$(echo "SHOW TABLES LIKE 'tabDocType';" | bench --site "$SITE_NAME" mariadb | grep 'tabDocType' || echo "")

# STEP 6: Run first-time installation or updates.
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