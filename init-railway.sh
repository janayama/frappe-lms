#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Frappe LMS Railway Production Setup - FINAL FIX ==="

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

# 3. Configure MySQL CLI client to use the correct remote host for all subprocesses.
# This is the definitive fix for the 'Access denied' error during installation.
echo "Configuring MySQL client with .my.cnf..."
cat > /home/frappe/.my.cnf <<EOF
[client]
host = ${DB_HOST}
port = ${DB_PORT}
user = ${DB_USER}
password = "${DB_PASSWORD}"
EOF
echo "MySQL client configured."

# 4. Aggressive Cleanup: Ensure a completely clean slate.
if [ -d "frappe-bench" ]; then
    echo "Found existing 'frappe-bench' directory. Wiping it to ensure a clean install."
    rm -rf frappe-bench
fi

# 5. Initialize Frappe Bench from scratch
echo "Creating new Frappe bench from a clean slate..."
bench init --skip-redis-config-generation frappe-bench
echo "Bench initialization complete."
cd frappe-bench

# 6. Manually patch Frappe source code
echo "Patching Frappe source for compatibility with modern MySQL..."
python3 -c "
import json, os, sys
workspace_json_path = './apps/frappe/frappe/desk/doctype/workspace/workspace.json'
if not os.path.exists(workspace_json_path):
    print(f'FATAL: Could not find {workspace_json_path} to patch.', file=sys.stderr)
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
    # No longer need to pass root credentials; they are in .my.cnf
    bench new-site "$SITE_NAME" \
        --db-type mariadb \
        --db-name "$DB_NAME" \
        --admin-password "$ADMIN_PASSWORD" \
        --force
    
    bench get-app lms
    bench --site "$SITE_NAME" install-app lms
    
    bench --site "$SITE_NAME" set-config developer_mode 0
    bench --site "$SITE_NAME" set-config -g serve_default_site true
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" clear-cache
    echo "Site '$SITE_NAME' created and installed successfully."
else
    echo "Site '$SITE_NAME' already installed. Skipping creation."
fi

# 8. Start production server
echo "Starting Gunicorn production server on port $APP_PORT..."
exec ./env/bin/gunicorn \
    --bind="0.0.0.0:$APP_PORT" \
    --workers=2 \
    --threads=4 \
    --worker-class=gthread \
    --preload \
    frappe.app:application 