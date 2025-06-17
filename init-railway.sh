#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Frappe LMS Railway Production Setup ==="

# Set environment variables with defaults for Railway
export SITE_NAME="${SITE_NAME:-lms.railway.app}"
export DB_HOST="${MYSQLHOST:-localhost}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_NAME="${MYSQLDATABASE:-railway}"
export DB_USER="${MYSQLUSER}"
export DB_PASSWORD="${MYSQLPASSWORD}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
export APP_PORT="${PORT:-8000}"

# 1. Start Redis Server in the background
echo "Starting Redis server..."
redis-server --daemonize yes
echo "Redis started."

# 2. Wait for Database to be ready
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Database not ready, retrying in 2 seconds..."
    sleep 2
done
echo "Database connection successful!"

# 3. Sanity check for Frappe installation. If it's incomplete, wipe it and start over.
if [ -d "frappe-bench" ] && [ ! -d "frappe-bench/apps/frappe" ]; then
    echo "Found an incomplete 'frappe-bench' directory. Wiping it to ensure a clean install."
    rm -rf frappe-bench
fi

# 4. Initialize Frappe Bench if it doesn't exist
if [ ! -d "frappe-bench" ]; then
    echo "Creating new Frappe bench..."
    bench init --skip-redis-config-generation frappe-bench
fi
cd frappe-bench

# 5. Manually patch Frappe source code to fix TEXT default value issue.
echo "Patching Frappe source for compatibility with modern MySQL..."
python3 -c "
import json
import os
import sys
# Path to the file that defines the 'Workspace' DocType.
workspace_json_path = 'apps/frappe/frappe/core/doctype/workspace/workspace.json'
if not os.path.exists(workspace_json_path):
    print(f'Error: Could not find {workspace_json_path} to patch.', file=sys.stderr)
    sys.exit(1)
try:
    with open(workspace_json_path, 'r') as f:
        doc = json.load(f)
    # Find the 'content' field and remove the 'default' key if it exists.
    for field in doc.get('fields', []):
        if field.get('fieldname') == 'content' and 'default' in field:
            print(\"Found and removing 'default' from 'content' field in workspace.json\")
            del field['default']
            break # Stop after finding the field
    # Write the patched file back.
    with open(workspace_json_path, 'w') as f:
        json.dump(doc, f, indent=1)
    print('Successfully patched workspace.json.')
except Exception as e:
    print(f'Error patching workspace.json: {e}', file=sys.stderr)
    sys.exit(1)
"

# 6. Create and install site only if it's not already installed properly.
if ! bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
    echo "Site '$SITE_NAME' is not installed correctly. Starting full installation..."
    
    # Configure global settings before creating the site
    bench set-config -g serve_default_site true

    bench new-site "$SITE_NAME" \
        --db-type mariadb \
        --mariadb-root-username "$DB_USER" \
        --mariadb-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --force \
        --no-mariadb-socket

    echo "Installing LMS app on site..."
    bench get-app lms
    bench --site "$SITE_NAME" install-app lms
    
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" clear-cache
    echo "Site '$SITE_NAME' created and installed successfully."
else
    echo "Site '$SITE_NAME' already installed. Skipping creation."
fi

# 7. Start the production server using gunicorn
echo "Starting Gunicorn production server on port $APP_PORT..."
exec ./env/bin/gunicorn \
    --bind="0.0.0.0:$APP_PORT" \
    --workers=2 \
    --threads=4 \
    --worker-class=gthread \
    --preload \
    frappe.app:application 