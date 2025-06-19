#!/bin/bash
set -e

# This script is the entrypoint for the Docker container.
# It sets up the Frappe environment based on Railway's environment variables.

# Navigate to the bench directory
cd /home/frappe/frappe-bench

# Set the site name from the SITE_NAME environment variable provided by Railway
# or default to a generic name if not set.
SITE_NAME=${SITE_NAME:-"lms.localhost"}

# Configure bench to use the Railway environment variables for database and Redis connections.
bench set-mariadb-host "$MARIADB_HOST"
bench set-redis-cache-host "redis://$REDIS_HOST:$REDIS_PORT"
bench set-redis-queue-host "redis://$REDIS_HOST:$REDIS_PORT"
bench set-redis-socketio-host "redis://$REDIS_HOST:$REDIS_PORT"

# Check if the site already exists.
if [ -d "sites/$SITE_NAME" ]; then
    echo "Site $SITE_NAME already exists. Skipping creation."
else
    echo "Site $SITE_NAME does not exist. Creating..."
    # Create a new site using the environment variables.
    # --no-mariadb-socket is important for connecting to a remote database.
    bench new-site "$SITE_NAME" \
        --db-name "$MARIADB_DATABASE" \
        --db-password "$MARIADB_PASSWORD" \
        --db-host "$MARIADB_HOST" \
        --db-port "$MARIADB_PORT" \
        --mariadb-root-username "$MARIADB_USER" \
        --mariadb-root-password "$MARIADB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket \
        --force
    
    # Install the 'lms' app on the newly created site.
    bench --site "$SITE_NAME" install-app lms
fi

# Set the developer_mode to 1 to allow for easier debugging if needed.
bench --site "$SITE_NAME" set-config developer_mode 1

# Run database migrations to ensure the schema is up to date.
bench --site "$SITE_NAME" migrate

# Start the Frappe server. This is the main process that will keep the container running.
bench start 