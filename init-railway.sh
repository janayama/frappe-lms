#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Frappe LMS Railway Production Setup - FINAL ATTEMPT ==="

# Set environment variables
export SITE_NAME="${SITE_NAME:-lms.railway.app}"
export DB_HOST="${MYSQLHOST:-localhost}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_NAME="${MYSQLDATABASE:-railway}"
export DB_USER="${MYSQLUSER}"
export DB_PASSWORD="${MYSQLPASSWORD}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
export APP_PORT="${PORT:-8000}"

# 1. Start Redis Server
echo "Starting Redis server..."
redis-server --daemonize yes
echo "Redis started."

# 2. Wait for Database
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Database not ready, retrying..."
    sleep 2
done
echo "Database connection successful!"

# 3. Aggressive Cleanup: Ensure a completely clean slate.
if [ -d "frappe-bench" ]; then
    echo "Found existing 'frappe-bench' directory. Wiping it completely to ensure a clean install."
    rm -rf frappe-bench
fi

# 4. Initialize Frappe Bench from scratch
echo "Creating new Frappe bench from a clean slate..."
bench init --skip-redis-config-generation frappe-bench
echo "Bench initialization complete."
cd frappe-bench

# 5. CRITICAL DIAGNOSTICS: Find the file we need to patch.
echo "--- DIAGNOSTICS START ---"
echo "Current directory: $(pwd)"
echo "Searching for workspace.json to verify Frappe installation..."
find . -name "workspace.json" -print -o -name "desktop.py" -print
echo "--- DIAGNOSTICS END ---"

# 6. Manually patch Frappe source code
echo "Patching Frappe source for compatibility with modern MySQL..."
python3 -c "
import json, os, sys
# This path is based on the standard Frappe app structure.
workspace_json_path = './apps/frappe/frappe/core/doctype/workspace/workspace.json'
if not os.path.exists(workspace_json_path):
    print(f'FATAL: Could not find {workspace_json_path} to patch.', file=sys.stderr)
    print('The Frappe app source code is missing or incomplete.', file=sys.stderr)
    sys.exit(1)
try:
    with open(workspace_json_path, 'r') as f: doc = json.load(f)
    for field in doc.get('fields', []):
        if field.get('fieldname') == 'content' and 'default' in field:
            print('Found and removing invalid default from workspace.json')
            del field['default']
            break
    with open(workspace_json_path, 'w') as f: json.dump(doc, f, indent=1)
    print('Successfully patched workspace.json.')
except Exception as e:
    print(f'Error patching workspace.json: {e}', file=sys.stderr)
    sys.exit(1)
"

# 7. Create and install site
if ! bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
    echo "Site '$SITE_NAME' not installed. Starting installation..."
    bench set-config -g serve_default_site true
    bench new-site "$SITE_NAME" --db-type mariadb --mariadb-root-username "$DB_USER" --mariadb-root-password "$DB_PASSWORD" --admin-password "$ADMIN_PASSWORD" --force --no-mariadb-socket
    bench get-app lms
    bench --site "$SITE_NAME" install-app lms
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" clear-cache
    echo "Site '$SITE_NAME' created and installed successfully."
else
    echo "Site '$SITE_NAME' already installed. Skipping creation."
fi

# 8. Start production server
echo "Starting Gunicorn production server on port $APP_PORT..."
exec ./env/bin/gunicorn --bind="0.0.0.0:$APP_PORT" --workers=2 --threads=4 --worker-class=gthread --preload frappe.app:application 