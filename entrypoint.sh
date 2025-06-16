#!/bin/bash
set -e

# Default values
SITE_NAME=${SITE_NAME:-lms.localhost}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
DB_HOST=${MYSQLHOST:-localhost}
DB_PORT=${MYSQLPORT:-3306}
DB_NAME=${MYSQLDATABASE:-lms_db}
DB_USER=${MYSQLUSER:-root}
DB_PASSWORD=${MYSQLPASSWORD:-admin}
PORT=${PORT:-8000}

echo "Starting Frappe LMS setup..."
echo "Site: $SITE_NAME"
echo "Database Host: $DB_HOST:$DB_PORT"
echo "Database Name: $DB_NAME"

# Wait for database to be ready
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Database not ready, waiting..."
  sleep 5
done
echo "Database connection established!"

# Create common site config
cat > sites/common_site_config.json << EOF
{
  "db_host": "$DB_HOST",
  "db_port": $DB_PORT,
  "redis_cache": "redis://localhost:6379",
  "redis_queue": "redis://localhost:6379",
  "redis_socketio": "redis://localhost:6379",
  "developer_mode": 0,
  "disable_website_cache": 1
}
EOF

# Check if site already exists
if [ ! -d "sites/$SITE_NAME" ]; then
  echo "Creating new site: $SITE_NAME"
  
  # Create the site
  bench new-site "$SITE_NAME" \
    --db-host "$DB_HOST" \
    --db-port "$DB_PORT" \
    --db-name "$DB_NAME" \
    --db-user "$DB_USER" \
    --db-password "$DB_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --no-mariadb-socket
  
  echo "Installing LMS app on site..."
  bench --site "$SITE_NAME" install-app lms
  
  echo "Setting up site configuration..."
  bench --site "$SITE_NAME" set-config developer_mode 0
  bench --site "$SITE_NAME" clear-cache
  bench --site "$SITE_NAME" build
else
  echo "Site $SITE_NAME already exists, skipping creation"
fi

# Migrate if needed
echo "Running migrations..."
bench --site "$SITE_NAME" migrate

# Start the application
echo "Starting Frappe LMS on port $PORT..."
exec bench serve --site "$SITE_NAME" --port "$PORT" --host 0.0.0.0 