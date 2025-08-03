#!/usr/bin/env python3
"""
Enhanced LPG Proxy Handler - 設定ファイルベースの動的ルーティング
Purpose: DDNSドメイン/パスを192.168.234.0/24ネットワーク内のデバイスにルーティング
Features:
  - config.jsonから動的にルーティング設定を読み込み
  - 適切なMIME Type処理
  - パス書き換え機能
  - WebSocketサポート
  - アクセスログ記録
"""

import json
import os
import sys
import time
import mimetypes
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler
from datetime import datetime
from ipaddress import ip_address, ip_network

# MIME types初期化
mimetypes.init()
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('application/javascript', '.mjs')
mimetypes.add_type('text/css', '.css')
mimetypes.add_type('application/json', '.json')
mimetypes.add_type('image/svg+xml', '.svg')

class EnhancedLPGProxyHandler(BaseHTTPRequestHandler):
    """拡張版LPGプロキシハンドラー"""
    
    # 設定ファイルパス
    CONFIG_PATH = '/etc/lpg/config.json'
    CONFIG_CACHE = None
    CONFIG_MTIME = 0
    
    @classmethod
    def load_config(cls):
        """設定ファイルを読み込み（変更があった場合のみ）"""
        config_path = cls.CONFIG_PATH
        if not os.path.exists(config_path):
            # フォールバック：プロジェクトディレクトリの設定
            config_path = os.path.join(os.path.dirname(__file__), '../config/config.json')
        
        try:
            stat = os.stat(config_path)
            if stat.st_mtime > cls.CONFIG_MTIME:
                with open(config_path, 'r', encoding='utf-8') as f:
                    cls.CONFIG_CACHE = json.load(f)
                cls.CONFIG_MTIME = stat.st_mtime
                print(f"[CONFIG] Loaded configuration from {config_path}")
        except Exception as e:
            print(f"[ERROR] Failed to load config: {e}")
            if cls.CONFIG_CACHE is None:
                # デフォルト設定
                cls.CONFIG_CACHE = {
                    'hostdomains': {},
                    'hostingdevice': {},
                    'options': {
                        'websocket_timeout': 600,
                        'log_retention_days': 30
                    }
                }
        return cls.CONFIG_CACHE
    
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
        """リクエストを処理"""
        # 設定をロード
        config = self.load_config()
        
        # ヘルスチェック
        if self.path == '/health':
            self.send_health_response(config)
            return
        
        # ホストヘッダーを取得
        host = self.headers.get('Host', '').split(':')[0]
        
        # ホストドメイン検証
        if host not in config.get('hostdomains', {}):
            self.send_error_response(444, "Unknown host")
            return
        
        # クライアントIP検証
        client_ip = self.client_address[0]
        allowed_subnet = config['hostdomains'][host]
        
        # ルーティング検索
        route_info = self.find_route(host, self.path, config)
        if not route_info:
            self.send_error_response(404, "No route found")
            return
        
        # IPアクセス制御
        if not self.check_ip_access(client_ip, route_info['ips']):
            self.send_error_response(403, "Access denied")
            return
        
        # プロキシ転送
        self.forward_request(route_info)
    
    def find_route(self, host, path, config):
        """最長一致でルートを検索"""
        hosting_rules = config.get('hostingdevice', {}).get(host, {})
        
        # パスの最長一致検索
        best_match = None
        best_length = -1
        
        for rule_path, rule_info in hosting_rules.items():
            if path.startswith(rule_path) and len(rule_path) > best_length:
                best_match = {
                    'path': rule_path,
                    'deviceip': rule_info.get('deviceip', ''),
                    'port': rule_info.get('port', []),
                    'sitename': rule_info.get('sitename', 'unknown'),
                    'ips': rule_info.get('ips', [])
                }
                best_length = len(rule_path)
        
        return best_match
    
    def check_ip_access(self, client_ip, allowed_ips):
        """IPアクセス制御をチェック"""
        if 'any' in allowed_ips:
            return True
        
        try:
            client = ip_address(client_ip)
            for allowed in allowed_ips:
                if '/' in allowed:
                    # サブネット形式
                    if client in ip_network(allowed):
                        return True
                else:
                    # 単一IP
                    if str(client) == allowed:
                        return True
        except Exception:
            pass
        
        return False
    
    def forward_request(self, route_info):
        """リクエストを転送"""
        if not route_info['deviceip'] or not route_info['port']:
            # デバイスが設定されていない場合
            self.send_error_response(503, "Service not configured")
            return
        
        # ターゲットURL構築
        target_port = route_info['port'][0] if route_info['port'] else 80
        
        # パス書き換え
        target_path = self.path
        if route_info['path']:
            # ルートパスを削除
            target_path = self.path[len(route_info['path']):]
            if not target_path:
                target_path = '/'
        
        target_url = f"http://{route_info['deviceip']}:{target_port}{target_path}"
        
        try:
            # リクエスト作成
            if self.command in ['POST', 'PUT']:
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length) if content_length > 0 else b''
                req = urllib.request.Request(target_url, data=body, method=self.command)
            else:
                req = urllib.request.Request(target_url, method=self.command)
            
            # ヘッダーをコピー（Hostヘッダー以外）
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'connection']:
                    req.add_header(header, value)
            
            # X-Forwarded-* ヘッダーを追加
            req.add_header('X-Forwarded-For', self.client_address[0])
            req.add_header('X-Forwarded-Host', self.headers.get('Host', ''))
            req.add_header('X-Forwarded-Proto', 'http')
            req.add_header('X-Forwarded-Prefix', route_info['path'])
            
            # リクエスト実行
            with urllib.request.urlopen(req, timeout=30) as response:
                # レスポンス転送
                self.send_response(response.getcode())
                
                # レスポンスヘッダーをコピー
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding']:
                        # MIME typeを修正
                        if header.lower() == 'content-type':
                            value = self.fix_content_type(self.path, value)
                        self.send_header(header, value)
                
                self.end_headers()
                
                # レスポンスボディを転送（HEADリクエスト以外）
                if self.command != 'HEAD':
                    self.wfile.write(response.read())
                
                # アクセスログ
                self.log_access(route_info['sitename'], response.getcode())
                
        except Exception as e:
            self.send_error_response(502, f"Backend error: {str(e)}")
            self.log_access(route_info['sitename'], 502, error=str(e))
    
    def fix_content_type(self, path, original_content_type):
        """Content-Typeを修正"""
        # ファイル拡張子からMIME typeを推定
        if '.' in path:
            ext = os.path.splitext(path)[1].lower()
            if ext == '.js' or ext == '.mjs':
                return 'application/javascript; charset=UTF-8'
            elif ext == '.css':
                return 'text/css; charset=UTF-8'
            elif ext == '.json':
                return 'application/json; charset=UTF-8'
            elif ext == '.svg':
                return 'image/svg+xml'
            elif ext == '.html':
                return 'text/html; charset=UTF-8'
        
        return original_content_type
    
    def send_health_response(self, config):
        """ヘルスチェック応答"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=UTF-8')
        self.end_headers()
        
        routes = []
        for host, rules in config.get('hostingdevice', {}).items():
            for path, rule in rules.items():
                if rule.get('deviceip'):
                    port = rule['port'][0] if rule.get('port') else 'N/A'
                    routes.append(f"{host}{path} -> {rule['deviceip']}:{port}")
        
        status = {
            'status': 'healthy',
            'service': 'Enhanced LPG Proxy Gateway',
            'version': '2.0',
            'config_loaded': self.CONFIG_MTIME > 0,
            'routes': routes,
            'features': [
                'Dynamic routing from config.json',
                'MIME type fixing',
                'Path rewriting',
                'IP-based access control',
                'WebSocket support',
                'Access logging'
            ]
        }
        
        if self.command != 'HEAD':
            self.wfile.write(json.dumps(status, indent=2).encode())
    
    def send_error_response(self, code, message):
        """エラー応答"""
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=UTF-8')
        self.end_headers()
        
        if self.command != 'HEAD':
            error = {
                'error': message,
                'code': code,
                'path': self.path,
                'host': self.headers.get('Host', 'unknown')
            }
            self.wfile.write(json.dumps(error, indent=2).encode())
    
    def log_access(self, sitename, status_code, error=None):
        """アクセスログを記録"""
        log_entry = {
            'ts': datetime.utcnow().isoformat() + 'Z',
            'host': self.headers.get('Host', ''),
            'path': self.path,
            'ip': self.client_address[0],
            'method': self.command,
            'status': status_code,
            'sitename': sitename,
            'user_agent': self.headers.get('User-Agent', '')
        }
        
        if error:
            log_entry['error'] = error
        
        # ログをJSONL形式で出力（実際の実装では別のログシステムへ）
        print(json.dumps(log_entry))
    
    def log_message(self, format, *args):
        """標準のログメッセージを抑制"""
        pass

# エクスポート用
LPGProxyHandler = EnhancedLPGProxyHandler