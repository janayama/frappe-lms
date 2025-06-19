# /frappe-lms/run_migrate.py
import os
import sys
import frappe

def main():
    """
    This script programmatically runs Frappe migrations.
    It bypasses the `bench migrate` command, which has proven unreliable
    for reading remote database configurations in this environment.
    """
    site = os.environ.get("SITE_NAME")
    if not site:
        print("ERROR: SITE_NAME environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    try:
        frappe.init(site=site)
        frappe.connect()
        print(f"Successfully connected to site {site}. Running migrations...")
        frappe.migrate.run(skip_files=True)
        print("Successfully completed migrations.")
    except Exception as e:
        print(f"An error occurred during migration: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        # It's crucial to close the database connection.
        if frappe.db:
            frappe.db.close()

if __name__ == "__main__":
    main() 