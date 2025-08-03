#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8080

# LacisDrawBoardsのindex.htmlを提供するシンプルなHTTPサーバー
class SimpleHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="/var/www/lacisdrawboards", **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

if __name__ == "__main__":
    print(f"Starting HTTP server on port {PORT}")
    print(f"Serving files from /var/www/lacisdrawboards")
    
    try:
        with socketserver.TCPServer(("", PORT), SimpleHTTPRequestHandler) as httpd:
            print(f"Server running at http://0.0.0.0:{PORT}/")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)