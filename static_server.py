#!/usr/bin/env python3

import os
import mimetypes
from pathlib import Path

class StaticFileMiddleware:
    """Simple WSGI middleware to serve static files"""
    
    def __init__(self, app, static_paths=None):
        self.app = app
        self.static_paths = static_paths or []
    
    def __call__(self, environ, start_response):
        path = environ.get('PATH_INFO', '').lstrip('/')
        method = environ.get('REQUEST_METHOD', 'GET')
        print(f"Processing request: {method} /{path}")
        
        # Check if this is a request for a static file
        for static_path in self.static_paths:
            file_path = Path(static_path) / path
            if file_path.exists() and file_path.is_file():
                print(f"Serving static file: {file_path}")
                return self.serve_static_file(file_path, environ, start_response)
        
        # Special handling for health check
        if path == 'health':
            site_name = os.environ.get('SITE_NAME', 'site1.local')
            health_file = Path(f'sites/{site_name}/public/health')
            if health_file.exists():
                print(f"Serving health check: {health_file}")
                return self.serve_static_file(health_file, environ, start_response)
        
        # Pass to the main application
        print(f"Passing to main application: /{path}")
        return self.app(environ, start_response)
    
    def serve_static_file(self, file_path, environ, start_response):
        """Serve a static file"""
        try:
            with open(file_path, 'rb') as f:
                content = f.read()
            
            # Determine content type
            content_type, _ = mimetypes.guess_type(str(file_path))
            if not content_type:
                content_type = 'application/octet-stream'
            
            # Send response
            status = '200 OK'
            headers = [
                ('Content-Type', content_type),
                ('Content-Length', str(len(content))),
                ('Cache-Control', 'public, max-age=3600'),
            ]
            start_response(status, headers)
            return [content]
            
        except Exception as e:
            # Return 404 if file can't be read
            status = '404 Not Found'
            headers = [('Content-Type', 'text/plain')]
            start_response(status, headers)
            return [b'File not found']

def create_app():
    """Create the WSGI application with static file middleware"""
    print("Creating WSGI application...")
    
    # Import Frappe application
    try:
        print("Attempting to import Frappe application...")
        import sys
        print(f"Python path: {sys.path}")
        
        # Set up Frappe environment
        import os
        os.environ.setdefault('FRAPPE_SITE', os.environ.get('SITE_NAME', 'site1.local'))
        
        from frappe.app import application as frappe_app
        print("Successfully imported Frappe application!")
        
    except ImportError as e:
        print(f"Failed to import Frappe application: {e}")
        # Fallback simple app if Frappe not available
        def simple_app(environ, start_response):
            path = environ.get('PATH_INFO', '/')
            print(f"Serving fallback app for path: {path}")
            
            status = '200 OK'
            headers = [('Content-Type', 'text/html')]
            start_response(status, headers)
            
            html = f'''
            <!DOCTYPE html>
            <html>
            <head>
                <title>Frappe LMS - Starting</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 40px; }}
                    .container {{ max-width: 600px; margin: 0 auto; }}
                    .error {{ background: #f8f8f8; padding: 20px; border-radius: 5px; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Frappe LMS is Starting...</h1>
                    <p>The application is initializing. Frappe framework import failed.</p>
                    <div class="error">
                        <h3>Debug Information:</h3>
                        <p><strong>Path requested:</strong> {path}</p>
                        <p><strong>Import error:</strong> {e}</p>
                        <p><strong>Site:</strong> {os.environ.get('SITE_NAME', 'Not set')}</p>
                    </div>
                    <p>Please wait while the system completes initialization...</p>
                </div>
            </body>
            </html>
            '''
            return [html.encode('utf-8')]
        frappe_app = simple_app
    
    except Exception as e:
        print(f"Unexpected error importing Frappe: {e}")
        def error_app(environ, start_response):
            status = '500 Internal Server Error'
            headers = [('Content-Type', 'text/html')]
            start_response(status, headers)
            return [f'<h1>Server Error</h1><p>Error: {e}</p>'.encode('utf-8')]
        frappe_app = error_app
    
    # Get site name for static paths
    site_name = os.environ.get('SITE_NAME', 'site1.local')
    static_paths = [
        f'sites/{site_name}/public',
        'sites/assets',
        'apps/frappe/frappe/public',
        'apps/lms/lms/public',
    ]
    
    print(f"Setting up static paths for site '{site_name}': {static_paths}")
    
    # Wrap with static file middleware
    app = StaticFileMiddleware(frappe_app, static_paths)
    print("WSGI application created successfully")
    return app

# Create the application
application = create_app() 