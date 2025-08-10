#!/usr/bin/env python3
"""
LPG Proxy - Path-based reverse proxy with path rewriting support
Version: 2.2.0
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error
import json
import logging
import os

# ロギング設定
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 設定ファイルのパス
CONFIG_FILE = '/opt/lpg/src/config.json'

class LPGProxyHandler(BaseHTTPRequestHandler):
    def load_config(self):
        """設定ファイルを読み込む"""
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return {}
    
    def do_GET(self):
        self.handle_request()
    
    def do_POST(self):
        self.handle_request()
    
    def do_HEAD(self):
        self.handle_request()
    
    def do_PUT(self):
        self.handle_request()
    
    def do_DELETE(self):
        self.handle_request()
    
    def do_OPTIONS(self):
        self.handle_request()
    
    def do_PATCH(self):
        self.handle_request()
    
    def handle_request(self):
        """リクエストを処理してバックエンドに転送"""
        config = self.load_config()
        host = self.headers.get('Host', '').split(':')[0]
        path = self.path
        
        # ホストドメインの確認
        if host not in config.get('hostdomains', {}):
            self.send_error(404, "Domain not configured")
            return
        
        # パスベースのルーティング
        hosting_rules = config.get('hostingdevice', {}).get(host, {})
        
        # 最長一致でルールを検索
        matched_rule = None
        matched_path = ""
        for rule_path in sorted(hosting_rules.keys(), key=len, reverse=True):
            if path.startswith(rule_path):
                matched_rule = hosting_rules[rule_path]
                matched_path = rule_path
                break
        
        if not matched_rule:
            self.send_error(404, "Path not configured")
            return
        
        # バックエンドのIPとポートを取得
        backend_ip = matched_rule.get('deviceip')
        backend_ports = matched_rule.get('port', [])
        
        if not backend_ip or not backend_ports:
            self.send_error(502, "Backend not configured")
            return
        
        # 最初のポートを使用（複数ポートの場合は負荷分散を実装可能）
        backend_port = backend_ports[0] if backend_ports else 80
        
        # パスの書き換え：プレフィックスを削除
        # /lacisstack/boards/xxx -> /xxx
        # /lacisstack/boards -> /
        # /lacisstack/boards/ -> /
        if matched_path and matched_path != '/':
            # matched_pathを削除してバックエンドパスを生成
            if path.startswith(matched_path):
                # パスからプレフィックスを削除
                backend_path = path[len(matched_path.rstrip('/')):]
                if not backend_path or backend_path == '/':
                    backend_path = '/'
                elif not backend_path.startswith('/'):
                    backend_path = '/' + backend_path
            else:
                backend_path = path
        else:
            backend_path = path
        
        # バックエンドURLを構築
        backend_url = f"http://{backend_ip}:{backend_port}{backend_path}"
        
        logger.info(f"Proxying {self.command} {path} -> {backend_url}")
        
        try:
            # リクエストをバックエンドに転送
            req = urllib.request.Request(backend_url, method=self.command)
            
            # ヘッダーをコピー（Host以外）
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'connection']:
                    req.add_header(header, value)
            
            # プロキシヘッダーを追加
            req.add_header('X-Forwarded-For', self.client_address[0])
            req.add_header('X-Forwarded-Host', host)
            req.add_header('X-Forwarded-Proto', 'https')
            req.add_header('X-Real-IP', self.client_address[0])
            req.add_header('X-Original-Path', path)
            
            # POSTデータがある場合
            if self.command in ['POST', 'PUT', 'PATCH']:
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    post_data = self.rfile.read(content_length)
                    req.data = post_data
            
            # バックエンドにリクエスト送信
            with urllib.request.urlopen(req, timeout=30) as response:
                # レスポンスを返す
                self.send_response(response.code)
                
                # レスポンスヘッダーを転送
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding', 'content-encoding']:
                        self.send_header(header, value)
                self.end_headers()
                
                # HEADメソッドの場合はボディを送らない
                if self.command != 'HEAD':
                    # ボディを転送（チャンク転送）
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                
        except urllib.error.HTTPError as e:
            logger.error(f"Backend returned HTTP error: {e.code} {e.reason}")
            self.send_error(e.code, e.reason)
        except urllib.error.URLError as e:
            logger.error(f"Backend connection error: {e}")
            self.send_error(502, "Backend connection failed")
        except Exception as e:
            logger.error(f"Proxy error: {e}")
            self.send_error(502, "Bad Gateway")
    
    def log_message(self, format, *args):
        """アクセスログ"""
        logger.info(f"{self.address_string()} - {format % args}")

if __name__ == '__main__':
    # 環境変数から設定を読み込み（デフォルトは127.0.0.1:8080）
    host = os.environ.get('LPG_PROXY_HOST', '127.0.0.1')
    port = int(os.environ.get('LPG_PROXY_PORT', '8080'))
    
    server = HTTPServer((host, port), LPGProxyHandler)
    logger.info(f'LPG Proxy listening on {host}:{port}')
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info('Shutting down LPG Proxy...')
        server.shutdown()
