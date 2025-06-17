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
        
        # Check if this is a request for a static file
        for static_path in self.static_paths:
            file_path = Path(static_path) / path
            if file_path.exists() and file_path.is_file():
                return self.serve_static_file(file_path, environ, start_response)
        
        # Special handling for health check
        if path == 'health':
            site_name = os.environ.get('SITE_NAME', 'site1.local')
            health_file = Path(f'sites/{site_name}/public/health')
            if health_file.exists():
                return self.serve_static_file(health_file, environ, start_response)
        
        # Pass to the main application
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
    # Import Frappe application
    try:
        from frappe.app import application as frappe_app
    except ImportError:
        # Fallback simple app if Frappe not available
        def simple_app(environ, start_response):
            status = '200 OK'
            headers = [('Content-Type', 'text/html')]
            start_response(status, headers)
            return [b'<h1>Frappe LMS Starting...</h1><p>Please wait while the application initializes.</p>']
        frappe_app = simple_app
    
    # Get site name for static paths
    site_name = os.environ.get('SITE_NAME', 'site1.local')
    static_paths = [
        f'sites/{site_name}/public',
        'sites/assets',
        'apps/frappe/frappe/public',
        'apps/lms/lms/public',
    ]
    
    # Wrap with static file middleware
    app = StaticFileMiddleware(frappe_app, static_paths)
    return app

# Create the application
application = create_app() 