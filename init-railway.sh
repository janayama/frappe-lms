#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Frappe LMS Railway Production Setup - DEFINITIVE FIX ==="

# Set environment variables
export SITE_NAME="${SITE_NAME:-lms.railway.app}"
export DB_HOST="${MARIADB_HOST:-localhost}"
export DB_PORT="${MARIADB_PORT:-3306}"
export DB_NAME="${MARIADB_DATABASE:-railway}"
export DB_USER="${MARIADB_USER}"
export DB_PASSWORD="${MARIADB_PASSWORD}"
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

# 5. Manually create the global config BEFORE running new-site.
echo "Creating global config (common_site_config.json) for the main application..."
python3 -c "
import json, os
config_path = 'sites/common_site_config.json'
config = {
    'db_host': os.environ.get('MARIADB_HOST'),
    'db_port': int(os.environ.get('MARIADB_PORT', 3306)),
    'redis_cache': 'redis://localhost:6379',
    'redis_queue': 'redis://localhost:6379',
    'redis_socketio': 'redis://localhost:6379',
    'serve_default_site': True,
    'socketio_port': 9000
}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print('--- common_site_config.json contents ---')
with open(config_path, 'r') as f:
    print(f.read())
print('----------------------------------------')
print('Global config created.')
"

# 6. Manually patch Frappe source code for BLOB/TEXT errors
echo "Patching Frappe source for compatibility with modern databases (strict sql_mode)..."
python3 -c "
import json, os, sys

def patch_doctype(path, field_to_patch):
    if not os.path.exists(path):
        print(f'WARNING: Could not find {path} to patch. Skipping.', file=sys.stderr)
        return

    try:
        with open(path, 'r') as f:
            doc = json.load(f)

        patched = False
        for field in doc.get('fields', []):
            if field.get('fieldname') == field_to_patch and 'default' in field:
                print(f'Found and removing invalid default for \"{field_to_patch}\" in {path}')
                del field['default']
                patched = True
                break
        
        if patched:
            with open(path, 'w') as f:
                json.dump(doc, f, indent=1)
            print(f'Successfully patched {path}.')
        else:
            # This is not an error, the field might just not have a default.
            print(f'Field \"{field_to_patch}\" in {path} did not require patching.')

    except Exception as e:
        print(f'ERROR: Failed to patch {path}: {e}', file=sys.stderr)
        # Do not exit, to allow other patches to be attempted.

# List of all known doctypes that are incompatible with strict MySQL.
# Format is: ('/path/to/file.json', 'field_name_to_fix')
patches = [
    ('./apps/frappe/frappe/desk/doctype/workspace/workspace.json', 'content'),
    ('./apps/frappe/frappe/email/doctype/notification/notification.json', 'message')
]

print(f'Applying {len(patches)} patches...')
for path, field_name in patches:
    patch_doctype(path, field_name)

print('Patching process complete.')
"

# 7. Manually create site configuration to bypass problematic user creation in new-site
echo "Manually creating site config for '$SITE_NAME' to bypass new-site helper..."
# Create the site directory and the necessary subdirectories for logs and files
mkdir -p "sites/$SITE_NAME/logs"
mkdir -p "sites/$SITE_NAME/public/files"
mkdir -p "sites/$SITE_NAME/private/files"

python3 -c "
import json, os
config_path = 'sites/$SITE_NAME/site_config.json'
config = {
    'db_name': os.environ.get('MARIADB_DATABASE'),
    'db_user': os.environ.get('MARIADB_USER'),
    'db_password': os.environ.get('MARIADB_PASSWORD'),
    'root_password': os.environ.get('MARIADB_PASSWORD'),
    'admin_password': os.environ.get('ADMIN_PASSWORD'),
    'db_host': os.environ.get('MARIADB_HOST'),
    'db_port': int(os.environ.get('MARIADB_PORT', 3306)),
    'db_type': 'mariadb'
}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print('--- site_config.json contents ---')
with open(config_path, 'r') as f:
    print(f.read())
print('---------------------------------')
print('Manual site config created.')
"

# 8. Manually import the initial database schema to bypass user creation logic.
echo "Manually importing base MariaDB framework schema..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < ./apps/frappe/frappe/database/mariadb/framework_mariadb.sql
echo "Base schema imported."

# 9. Install apps. This will also run schema migrations.
echo "Site '$SITE_NAME' configured. Installing apps..."
bench use "$SITE_NAME"

echo "Installing Frappe framework..."
bench --site "$SITE_NAME" install-app frappe

echo "Getting LMS app from local repository source..."
# Since Railway has already cloned the repo, we can install the app from the local path.
bench get-app ../

echo "Installing LMS app..."
bench --site "$SITE_NAME" install-app lms

echo "Setting production mode and clearing cache..."
bench --site "$SITE_NAME" set-config developer_mode 0
bench --site "$SITE_NAME" clear-cache
echo "Site '$SITE_NAME' created and installed successfully."

# 10. Start production servers
echo "Starting Socket.IO server in the background..."
node socketio.js &

echo "Starting Gunicorn production server on port $APP_PORT..."
exec ./env/bin/gunicorn \
    --bind="0.0.0.0:$APP_PORT" \
    --workers=2 \
    --threads=4 \
    --worker-class=gthread \
    --preload \
    frappe.app:application 