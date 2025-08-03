#!/usr/bin/env python3
"""
LPG (Lacis Proxy Gateway) - Simple HTTP Proxy Server
Routes requests based on path to backend services
Updated to route LacisDrawBoards to port 8080
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request
from urllib.error import URLError
import json
import socket
import sys

# Routing configuration - All services on port 8080
ROUTES = {
    '/lacisstack/boards': {
        'host': '192.168.234.10',
        'port': 8080,
        'strip_prefix': False
    },
    '/lacisstack/boards/ws': {
        'host': '192.168.234.10', 
        'port': 8081,  # WebSocket on different port
        'strip_prefix': False
    },
    '/lacisstack/api': {
        'host': '192.168.234.10',
        'port': 8080,  # API also on 8080
        'strip_prefix': False
    },
    '/lacisstack': {
        'host': '192.168.234.10',
        'port': 8080,
        'strip_prefix': False
    }
}

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()
    
    def do_POST(self):
        self.handle_request()
    
    def do_PUT(self):
        self.handle_request()
    
    def do_DELETE(self):
        self.handle_request()
    
    def do_HEAD(self):
        self.handle_request()
    
    def do_OPTIONS(self):
        self.handle_request()
    
    def handle_request(self):
        # Health check endpoint
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            health_data = {
                'status': 'healthy',
                'service': 'LPG Proxy Gateway',
                'version': '1.1',
                'updated': '2025-08-01',
                'routes': [f"{path} -> {route['host']}:{route['port']}" for path, route in ROUTES.items()]
            }
            self.wfile.write(json.dumps(health_data, indent=2).encode())
            return
        
        # Find matching route (longest match first)
        target_route = None
        matched_path = None
        
        sorted_routes = sorted(ROUTES.items(), key=lambda x: len(x[0]), reverse=True)
        
        for route_path, route_config in sorted_routes:
            if self.path.startswith(route_path):
                target_route = route_config
                matched_path = route_path
                break
        
        if not target_route:
            self.send_error(404, 'Route not found')
            return
        
        # Build target URL
        target_host = target_route['host']
        target_port = target_route['port']
        
        if target_route.get('strip_prefix', False):
            target_path = self.path[len(matched_path):]
            if not target_path.startswith('/'):
                target_path = '/' + target_path
        else:
            target_path = self.path
        
        target_url = f"http://{target_host}:{target_port}{target_path}"
        
        try:
            # Forward the request
            headers = dict(self.headers)
            
            # Add forwarding headers
            client_ip = self.client_address[0]
            headers['X-Forwarded-For'] = headers.get('X-Forwarded-For', '') + f', {client_ip}'
            headers['X-Forwarded-Host'] = self.headers.get('Host', 'lpg.local')
            headers['X-Forwarded-Prefix'] = matched_path
            headers['X-Real-IP'] = client_ip
            
            # Remove hop-by-hop headers
            for header in ['connection', 'keep-alive', 'transfer-encoding', 'upgrade']:
                headers.pop(header, None)
            
            # Read request body if present
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Make the request
            req = Request(target_url, data=body, headers=headers, method=self.command)
            
            with urlopen(req, timeout=30) as response:
                # Send response status
                self.send_response(response.getcode())
                
                # Forward response headers
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding']:
                        self.send_header(header, value)
                self.end_headers()
                
                # Forward response body
                while True:
                    chunk = response.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    
        except URLError as e:
            # Handle connection errors
            self.send_response(503)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            
            error_html = f"""
            <html>
            <head><title>LPG Proxy - Service Unavailable</title></head>
            <body style="font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto;">
            <h1>LPG Proxy Gateway</h1>
            <h2 style="color: #d32f2f;">Target Service Unavailable</h2>
            <p>Unable to connect to backend service.</p>
            <div style="background: #f5f5f5; padding: 10px; border-radius: 5px; margin: 20px 0;">
                <strong>Target URL:</strong> {target_url}<br>
                <strong>Error:</strong> {e}<br>
                <strong>Route:</strong> {matched_path} → {target_host}:{target_port}
            </div>
            <p><em>This error indicates that LPG is correctly routing the request, but the target service at {target_host}:{target_port} is not responding.</em></p>
            <hr>
            <small>LPG v1.1 - {self.log_date_time_string()}</small>
            </body>
            </html>
            """
            self.wfile.write(error_html.encode())
        
        except Exception as e:
            self.send_error(500, f'Proxy error: {str(e)}')
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        sys.stderr.write(f"[{self.log_date_time_string()}] {format%args}\n")

def run_server(port=80):
    """Run the proxy server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, ProxyHandler)
    
    print(f"LPG Proxy Server v1.1 starting on port {port}")
    print("Routes configured:")
    for path, route in sorted(ROUTES.items(), key=lambda x: x[0]):
        print(f"  {path} -> {route['host']}:{route['port']}")
    print(f"\nListening on all interfaces (0.0.0.0:{port})")
    print("Updated: 2025-08-01 - All services routed to port 8080")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down proxy server...")
        httpd.shutdown()

if __name__ == '__main__':
    # Run on port 80 (requires root or CAP_NET_BIND_SERVICE)
    port = 80
    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    
    run_server(port)
