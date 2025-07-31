#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error
import json

class LPGProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            status = {
                'status': 'healthy',
                'service': 'LPG Proxy Gateway',
                'version': '1.0',
                'routes': [
                    '/lacisstack/boards -> 192.168.234.10:8080'
                ]
            }
            self.wfile.write(json.dumps(status).encode())
        elif self.path.startswith('/lacisstack/boards'):
            # Try to forward to Orange Pi 5 Plus
            target_path = self.path.replace('/lacisstack/boards', '')
            if not target_path:
                target_path = '/'
            target_url = f'http://192.168.234.10:8080{target_path}'
            
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
                
                with urllib.request.urlopen(req, timeout=5) as response:
                    self.send_response(response.getcode())
                    for header, value in response.headers.items():
                        self.send_header(header, value)
                    self.end_headers()
                    self.wfile.write(response.read())
            except (urllib.error.URLError, ConnectionRefusedError) as e:
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
<p>Route: /lacisstack/boards → 192.168.234.10:8080</p>
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