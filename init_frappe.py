#!/usr/bin/env python3

import os
import sys
import json
import mysql.connector
from pathlib import Path

def init_frappe_site():
    """Initialize Frappe site without bench commands"""
    
    # Get environment variables
    site_name = os.environ.get('SITE_NAME', 'site1.local')
    db_host = os.environ.get('DB_HOST', 'localhost')
    db_port = int(os.environ.get('DB_PORT', '3306'))
    db_user = os.environ.get('DB_USER', 'root')
    db_password = os.environ.get('DB_PASSWORD', '')
    db_name = os.environ.get('DB_NAME', 'frappe_lms')
    admin_password = os.environ.get('ADMIN_PASSWORD', 'admin')
    
    print(f"=== Python Script Environment Variables ===")
    print(f"SITE_NAME: {site_name}")
    print(f"DB_HOST: {db_host}")
    print(f"DB_PORT: {db_port}")
    print(f"DB_USER: {db_user}")
    print(f"DB_PASSWORD: [{'*' * len(db_password) if db_password else 'EMPTY'}]")
    print(f"DB_NAME: {db_name}")
    print(f"ADMIN_PASSWORD: [{'*' * len(admin_password) if admin_password else 'EMPTY'}]")
    print(f"===========================================")
    
    print(f"Initializing Frappe site: {site_name}")
    print(f"Database: {db_host}:{db_port}/{db_name}")
    
    try:
        # Connect to MySQL
        connection = mysql.connector.connect(
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
            database=db_name
        )
        cursor = connection.cursor()
        
        # Check if site is already initialized
        try:
            cursor.execute("SELECT COUNT(*) FROM tabSingles WHERE doctype = 'System Settings'")
            result = cursor.fetchone()
            if result and result[0] > 0:
                print("Site already initialized, skipping setup")
                return True
        except mysql.connector.Error:
            print("Site not initialized yet, proceeding with setup")
        
        # Create basic Frappe tables
        print("Creating basic Frappe database structure...")
        
        # Create tabSingles table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `tabSingles` (
              `doctype` varchar(255) NOT NULL,
              `field` varchar(255) NOT NULL,
              `value` longtext,
              PRIMARY KEY (`doctype`,`field`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """)
        
        # Create tabSessions table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `tabSessions` (
              `name` varchar(255) NOT NULL,
              `creation` datetime(6) DEFAULT NULL,
              `modified` datetime(6) DEFAULT NULL,
              `modified_by` varchar(255) DEFAULT NULL,
              `owner` varchar(255) DEFAULT NULL,
              `docstatus` int(1) NOT NULL DEFAULT '0',
              `idx` int(8) NOT NULL DEFAULT '0',
              `user` varchar(255) DEFAULT NULL,
              `sid` varchar(255) DEFAULT NULL,
              `sessiondata` longtext,
              `ipaddress` varchar(16) DEFAULT NULL,
              `lastupdate` datetime(6) DEFAULT NULL,
              `device` varchar(255) DEFAULT 'desktop',
              `status` varchar(20) DEFAULT 'Active',
              PRIMARY KEY (`name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """)
        
        # Insert basic system settings
        settings = [
            ('System Settings', 'country', ''),
            ('System Settings', 'time_zone', 'UTC'),
            ('System Settings', 'date_format', 'yyyy-mm-dd'),
            ('System Settings', 'first_day_of_the_week', 'Monday'),
            ('System Settings', 'language', 'en'),
            ('System Settings', 'setup_complete', '1'),
        ]
        
        for doctype, field, value in settings:
            cursor.execute("""
                INSERT IGNORE INTO `tabSingles` (`doctype`, `field`, `value`) 
                VALUES (%s, %s, %s)
            """, (doctype, field, value))
        
        connection.commit()
        print("Basic database structure created successfully")
        
        cursor.close()
        connection.close()
        
        return True
        
    except mysql.connector.Error as e:
        print(f"Database error: {e}")
        return False
    except Exception as e:
        print(f"Error initializing site: {e}")
        return False

if __name__ == "__main__":
    success = init_frappe_site()
    sys.exit(0 if success else 1) 