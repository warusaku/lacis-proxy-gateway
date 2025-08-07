#!/bin/bash

# 管理UIのHTTPS化スクリプト
# 作成日: 2025-08-04
# 目的: LPG管理UI（ポート8443）をHTTPSに対応させる

echo "=== LPG管理UI HTTPS設定 ==="
echo ""

ssh -i ~/.ssh/id_ed25519_lpg -o StrictHostKeyChecking=no root@192.168.234.2 << 'REMOTE_SCRIPT'

# 1. 自己署名証明書の生成
echo "1. 自己署名SSL証明書を生成..."
mkdir -p /opt/lpg/ssl
cd /opt/lpg/ssl

# 証明書がなければ生成
if [ ! -f server.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout server.key \
        -out server.crt \
        -subj "/C=JP/ST=Tokyo/L=Tokyo/O=LACIS/OU=IT/CN=lpg-admin.local"
    
    echo "SSL証明書を生成しました"
else
    echo "既存のSSL証明書を使用"
fi

# 2. lpg_admin.pyを修正してHTTPS対応
echo ""
echo "2. lpg_admin.pyをHTTPS対応に修正..."

cd /opt/lpg/src

# バックアップ作成
cp lpg_admin.py lpg_admin.py.bak.$(date +%Y%m%d_%H%M%S)

# HTTPS対応版のlpg_admin.pyを作成
cat > lpg_admin_https.py << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
LPG Admin Web UI - HTTPS対応版
"""
import os
import json
import hashlib
import secrets
import ssl
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import threading
import time
import logging

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', secrets.token_hex(32))

# 設定ファイルパス
CONFIG_FILE = '/opt/lpg/config.json'

# 簡易認証設定
ADMIN_USERNAME = os.environ.get('LPG_ADMIN_USER', 'admin')
ADMIN_PASSWORD_HASH = hashlib.sha256(
    os.environ.get('LPG_ADMIN_PASS', 'lpgadmin123').encode()
).hexdigest()

# セッションタイムアウト（24時間）
app.permanent_session_lifetime = timedelta(hours=24)

# メトリクス保存用
metrics_data = {
    'cpu_usage': 0,
    'memory_usage': 0,
    'requests_total': 0,
    'requests_per_minute': []
}

def load_config():
    """設定ファイルを読み込む"""
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            'hostdomains': {},
            'hostingdevice': {},
            'adminuser': {},
            'endpoint': {}
        }

def save_config(config):
    """設定ファイルを保存する"""
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

def login_required(f):
    """ログイン必須デコレータ"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def index():
    """ルートページ"""
    if 'logged_in' in session:
        return redirect(url_for('topology'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """ログインページ"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if username == ADMIN_USERNAME and password_hash == ADMIN_PASSWORD_HASH:
            session['logged_in'] = True
            session['username'] = username
            session.permanent = True
            return redirect(url_for('topology'))
        else:
            return render_template('login_dark.html', error='Invalid credentials')
    
    return render_template('login_dark.html')

@app.route('/logout')
def logout():
    """ログアウト"""
    session.clear()
    return redirect(url_for('login'))

@app.route('/topology')
@login_required
def topology():
    """システムトポロジービュー"""
    config = load_config()
    
    # configからdomainsとdevicesデータを構築
    domains = []
    devices = []
    
    # hostdomainsから基本的なdomainデータを構築
    for domain_name, subnet in config.get('hostdomains', {}).items():
        domains.append({
            'domain_name': domain_name,
            'status': 'active',
            'connection_count': 0,
            'display_name': domain_name,
            'allowed_subnets': [subnet] if isinstance(subnet, str) else subnet,
            'lpg_ip': '192.168.234.2',
            'connection_type': 'HTTP',
            'speed': '100 Mbps',
            'id': len(domains),
            'registration_path': '/'
        })
    
    # hostingdeviceからdeviceデータを構築
    for domain_name, paths in config.get('hostingdevice', {}).items():
        if isinstance(paths, dict):
            for path, device_info in paths.items():
                if device_info and device_info.get('deviceip'):
                    devices.append({
                        'ip_address': device_info['deviceip'],
                        'status': 'active',
                        'device_name': device_info.get('sitename', 'Device'),
                        'registration_path': path,
                        'port': device_info.get('port', [80])[0] if device_info.get('port') else 80,
                        'domain_id': next((i for i, d in enumerate(domains) if d['domain_name'] == domain_name), 0)
                    })
    
    # メトリクスデータ
    metrics = {
        'active_connections': len(devices),
        'total_domains': len(domains),
        'total_devices': len(devices),
        'uptime': '24h',
        'bandwidth': '1.2 GB/s'
    }
    
    from datetime import datetime
    return render_template('topology_v2.html', 
                         config=config, 
                         domains=domains, 
                         devices=devices, 
                         metrics=metrics,
                         current_time=datetime.now().strftime('%H:%M:%S'))

@app.route('/devices')
@login_required
def devices():
    """デバイス一覧"""
    config = load_config()
    devices = []
    
    for domain_name, paths in config.get('hostingdevice', {}).items():
        if isinstance(paths, dict):
            for path, device_info in paths.items():
                if device_info and device_info.get('deviceip'):
                    devices.append({
                        'device_name': device_info.get('sitename', 'Unknown'),
                        'ip_address': device_info['deviceip'],
                        'port': device_info.get('port', [80])[0] if device_info.get('port') else 80,
                        'registration_path': path,
                        'domain_name': domain_name,
                        'status': 'active'
                    })
    
    return render_template('devices.html', devices=devices)

if __name__ == '__main__':
    # SSL context設定
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    context.load_cert_chain('/opt/lpg/ssl/server.crt', '/opt/lpg/ssl/server.key')
    
    # HTTPS対応でFlaskアプリを起動
    app.run(
        host='0.0.0.0',
        port=8443,
        debug=False,
        ssl_context=context
    )
PYTHON_EOF

# 3. 既存のlpg_admin.pyを停止
echo ""
echo "3. 既存のlpg_admin.pyを停止..."
pkill -f lpg_admin.py

# 4. HTTPS版を起動
echo ""
echo "4. HTTPS版lpg_adminを起動..."
cd /opt/lpg/src
nohup python3 lpg_admin_https.py > /var/log/lpg_admin_https.log 2>&1 &

sleep 3

# 5. プロセス確認
echo ""
echo "5. プロセス確認..."
ps aux | grep lpg_admin | grep -v grep

# 6. HTTPS接続テスト
echo ""
echo "6. HTTPS接続テスト..."
curl -k -s -o /dev/null -w "HTTPS Status: %{http_code}\n" https://localhost:8443/

# 7. ログ確認
echo ""
echo "7. 起動ログ確認..."
tail -20 /var/log/lpg_admin_https.log

echo ""
echo "=== HTTPS設定完了 ==="
echo ""
echo "アクセス方法:"
echo "  https://192.168.234.2:8443/"
echo ""
echo "証明書情報:"
echo "  場所: /opt/lpg/ssl/"
echo "  タイプ: 自己署名証明書"
echo "  有効期限: 1年間"
REMOTE_SCRIPT

echo ""
echo "ローカルからのテスト:"
curl -k -s -o /dev/null -w "HTTPS接続テスト: %{http_code}\n" https://192.168.234.2:8443/