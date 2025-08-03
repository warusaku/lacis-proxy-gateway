#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error
import json

class LPGProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Override to add custom logging"""
        print(f"[PROXY] {self.client_address[0]} - {format % args}")
    
    def do_GET(self):
        print(f"[DEBUG] Received request: {self.path}")
        
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            status = {
                'status': 'healthy',
                'service': 'LPG Proxy Gateway',
                'version': '1.0',
                'routes': [
                    '/lacisstack/boards -> 192.168.234.2:80'
                ]
            }
            self.wfile.write(json.dumps(status).encode())
        elif self.path.startswith('/lacisstack/boards'):
            # Try to forward to LacisDrawBoards
            target_path = self.path.replace('/lacisstack/boards', '')
            if not target_path:
                target_path = '/'
            
            target_url = f'http://192.168.234.2:80{target_path}'
            print(f"[DEBUG] Forwarding {self.path} -> {target_url}")
            
            try:
                # Attempt to forward request
                req = urllib.request.Request(target_url)
                # Copy headers
                for header in self.headers:
                    if header.lower() not in ['host']:
                        req.add_header(header, self.headers[header])
                req.add_header('X-Forwarded-For', self.client_address[0])
                req.add_header('X-Forwarded-Host', self.headers.get('Host', ''))
                req.add_header('X-Forwarded-Prefix', '/lacisstack/boards')
                
                with urllib.request.urlopen(req, timeout=10) as response:
                    print(f"[DEBUG] Response from {target_url}: {response.getcode()}")
                    self.send_response(response.getcode())
                    
                    # Handle CORS headers for JavaScript files
                    content_type = response.headers.get('Content-Type', '')
                    if target_path.endswith('.js'):
                        self.send_header('Content-Type', 'application/javascript')
                        self.send_header('Access-Control-Allow-Origin', '*')
                    elif target_path.endswith('.css'):
                        self.send_header('Content-Type', 'text/css')
                        self.send_header('Access-Control-Allow-Origin', '*')
                    
                    # Copy other headers
                    for header, value in response.headers.items():
                        if header.lower() not in ['content-type']:  # Skip content-type if we set it above
                            self.send_header(header, value)
                    
                    self.end_headers()
                    content = response.read()
                    print(f"[DEBUG] Forwarded {len(content)} bytes for {target_path}")
                    self.wfile.write(content)
                    
            except urllib.error.HTTPError as e:
                print(f"[ERROR] HTTP Error {e.code} for {target_url}: {e.reason}")
                self.send_response(e.code)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                error_html = f'''
<html>
<head><title>LPG Proxy - HTTP Error {e.code}</title></head>
<body>
<h1>LPG Proxy Gateway</h1>
<h2>HTTP Error {e.code}</h2>
<p>Request: {self.path}</p>
<p>Target: {target_url}</p>
<p>Error: {e.reason}</p>
<hr>
<p>The target server returned an error.</p>
</body>
</html>
'''
                self.wfile.write(error_html.encode())
            except (urllib.error.URLError, ConnectionRefusedError) as e:
                print(f"[ERROR] Connection failed to {target_url}: {str(e)}")
                # Target not available
                self.send_response(503)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                error_html = f'''
<html>
<head><title>LPG Proxy - Service Unavailable</title></head>
<body>
<h1>LPG Proxy Gateway</h1>
<h2>Target Service Unavailable</h2>
<p>Unable to connect to: {target_url}</p>
<p>Error: {str(e)}</p>
<hr>
<p>Route: /lacisstack/boards → 192.168.234.2:80</p>
<p>This demonstrates that LPG is correctly routing the request.</p>
</body>
</html>
'''
                self.wfile.write(error_html.encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>LPG Proxy Gateway</h1><p>Ready</p>')

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 80), LPGProxyHandler)
    print('LPG Proxy listening on port 80')
    server.serve_forever()