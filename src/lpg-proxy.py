#\!/usr/bin/env python3
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
        
        # バックエンドURLを構築
        backend_url = f"http://{backend_ip}:{backend_port}{path}"
        
        try:
            # リクエストをバックエンドに転送
            req = urllib.request.Request(backend_url)
            
            # ヘッダーをコピー
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'connection']:
                    req.add_header(header, value)
            
            # POSTデータがある場合
            if self.command == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                req.data = post_data
            
            # バックエンドにリクエスト送信
            with urllib.request.urlopen(req) as response:
                # レスポンスを返す
                self.send_response(response.code)
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding']:
                        self.send_header(header, value)
                self.end_headers()
                
                # ボディを転送
                self.wfile.write(response.read())
                
        except urllib.error.HTTPError as e:
            self.send_error(e.code, e.reason)
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
    server.serve_forever()
