#!/usr/bin/env python3
"""
LPG Server - 統合プロキシサーバー + 管理UI
"""
import os
import sys
import json
import threading
import signal
from http.server import HTTPServer
from urllib.parse import urlparse

# Flaskアプリをインポート
from lpg_admin import app

# プロキシハンドラーをインポート
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from update_proxy_simple import LPGProxyHandler

# 設定
PROXY_PORT = 80
ADMIN_PORT = 8443

def run_proxy_server():
    """プロキシサーバーを起動"""
    print(f"Starting LPG Proxy on port {PROXY_PORT}...")
    server = HTTPServer(('0.0.0.0', PROXY_PORT), LPGProxyHandler)
    server.serve_forever()

def run_admin_server():
    """管理UIサーバーを起動"""
    print(f"Starting LPG Admin UI on port {ADMIN_PORT}...")
    # SSL証明書が必要な場合は生成
    ssl_context = None
    if ADMIN_PORT == 8443:
        try:
            import ssl
            ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            # 自己署名証明書を使用（本番環境では適切な証明書を使用）
            cert_file = '/etc/lpg/certs/server.crt'
            key_file = '/etc/lpg/certs/server.key'
            
            if not os.path.exists(cert_file):
                # 簡易的な自己署名証明書生成
                os.makedirs('/etc/lpg/certs', exist_ok=True)
                os.system(f'openssl req -x509 -newkey rsa:4096 -keyout {key_file} -out {cert_file} -days 365 -nodes -subj "/CN=lpg.local"')
            
            ssl_context.load_cert_chain(cert_file, key_file)
        except Exception as e:
            print(f"SSL setup failed, using HTTP: {e}")
            ssl_context = None
    
    app.run(host='0.0.0.0', port=ADMIN_PORT, ssl_context=ssl_context, debug=False)

def signal_handler(sig, frame):
    """シグナルハンドラー"""
    print("\nShutting down LPG Server...")
    sys.exit(0)

def main():
    """メイン関数"""
    # シグナルハンドラー設定
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print("=== LacisProxyGateway Server ===")
    print(f"Proxy: http://0.0.0.0:{PROXY_PORT}")
    print(f"Admin: https://0.0.0.0:{ADMIN_PORT}")
    print("Default login: admin / lpgadmin123")
    print("================================")
    
    # プロキシサーバーを別スレッドで起動
    proxy_thread = threading.Thread(target=run_proxy_server, daemon=True)
    proxy_thread.start()
    
    # 管理UIサーバーをメインスレッドで起動
    run_admin_server()

if __name__ == '__main__':
    main()