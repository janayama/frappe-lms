import os
import sys
import frappe

def main():
    """
    This script programmatically runs Frappe migrations.
    It takes the site name as a command-line argument to ensure reliability.
    """
    if len(sys.argv) < 2:
        print("ERROR: Site name must be provided as a command-line argument.", file=sys.stderr)
        sys.exit(1)

    site = sys.argv[1]

    try:
        frappe.init(site=site)
        frappe.connect()
        print(f"--- [run_migrate.py] Successfully connected to site {site}. Running migrations... ---")
        frappe.migrate.run(skip_files=True)
        print(f"--- [run_migrate.py] Successfully completed migrations for site {site}. ---")
    except Exception as e:
        print(f"--- [run_migrate.py] An error occurred during migration: {e} ---", file=sys.stderr)
        # In case of an error, print the full traceback
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        # It's crucial to close the database connection.
        if frappe.db:
            frappe.db.close()

if __name__ == "__main__":
    main() 