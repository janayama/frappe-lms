#!/usr/bin/env python3

import os
import sys
from wsgiref.simple_server import make_server, WSGIServer
from socketserver import ThreadingMixIn
import logging
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ThreadingWSGIServer(ThreadingMixIn, WSGIServer):
    daemon_threads = True

def simple_health_check(environ, start_response):
    """Ultra-simple health check that just returns OK"""
    if environ['PATH_INFO'] == '/health':
        status = '200 OK'
        headers = [('Content-Type', 'text/plain')]
        start_response(status, headers)
        return [b'OK']
    
    # For all other requests, let Frappe handle them
    return None

def application(environ, start_response):
    """Main WSGI application"""
    
    # Handle health check immediately
    health_response = simple_health_check(environ, start_response)
    if health_response is not None:
        return health_response
    
    # Import Frappe only when needed (not for health checks)
    try:
        import frappe
        import frappe.app
        
        # Initialize Frappe if not already done
        if not getattr(frappe.local, 'initialised', False):
            frappe.init(site=os.environ.get('SITE_NAME', 'localhost'))
            frappe.local.initialised = True
        
        # Use Frappe's WSGI application
        return frappe.app.application(environ, start_response)
    
    except Exception as e:
        logger.error(f"Error in Frappe application: {e}")
        status = '500 Internal Server Error'
        headers = [('Content-Type', 'text/plain')]
        start_response(status, headers)
        return [f'Error: {str(e)}'.encode()]

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    host = '0.0.0.0'
    
    logger.info(f"Starting server on {host}:{port}")
    
    # Use threading server for better performance
    httpd = make_server(host, port, application, server_class=ThreadingWSGIServer)
    
    logger.info("Server started successfully")
    httpd.serve_forever() 