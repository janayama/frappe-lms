#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set the site name from the SITE_NAME environment variable provided by Railway
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# Configure bench to use the Railway environment variables for Redis.
# The REDIS_URL variable contains all connection info, including the password.
bench set-redis-cache-host "$REDIS_URL"
bench set-redis-queue-host "$REDIS_URL"
bench set-redis-socketio-host "$REDIS_URL"

# Check if the site directory exists. If not, this is the first deployment.
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Site $SITE_NAME does not exist. Creating and installing for the first time..."

    # 1. Manually create the site directory and the site_config.json file.
    # This is the key to bypassing the 'new-site' command's user creation,
    # which fails on managed databases.
    mkdir -p sites/$SITE_NAME
    cat <<EOF > sites/$SITE_NAME/site_config.json
{
    "db_host": "$MARIADB_HOST",
    "db_name": "$MARIADB_DATABASE",
    "db_password": "$MARIADB_PASSWORD",
    "db_port": $MARIADB_PORT,
    "db_user": "$MARIADB_USER",
    "developer_mode": 1
}
EOF
    # 2. Add the site to the list of sites for the bench.
    echo "$SITE_NAME" > sites/common_site_config.json

    # 3. Use 'reinstall' to populate the database.
    # This creates all the base Frappe tables and the Administrator user
    # using the credentials we just provided in site_config.json.
    bench --site "$SITE_NAME" reinstall --yes --admin-password "$ADMIN_PASSWORD"

    # 4. Install the 'lms' app on the newly created site.
    bench --site "$SITE_NAME" install-app lms
else
    echo "Site $SITE_NAME already exists. Skipping first-time installation."
fi

# Run database migrations to ensure the schema is up to date on every deploy.
bench --site "$SITE_NAME" migrate

# Start the Frappe server.
bench start 