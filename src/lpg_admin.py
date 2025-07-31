#!/usr/bin/env python3
"""
LPG Admin Web UI - 簡易管理インターフェース
"""
import os
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import threading
import time

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', secrets.token_hex(32))

# 設定ファイルパス
CONFIG_FILE = '/etc/lpg/config.json'
if not os.path.exists(CONFIG_FILE):
    CONFIG_FILE = './config/config.json'

# 簡易認証設定（本番環境では環境変数から取得）
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
            'endpoint': {'logserver': ''},
            'options': {}
        }
    except Exception as e:
        print(f"Error loading config: {e}")
        return {}

def save_config(config):
    """設定ファイルを保存"""
    try:
        # バックアップを作成
        if os.path.exists(CONFIG_FILE):
            backup_file = f"{CONFIG_FILE}.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            with open(CONFIG_FILE, 'r') as f:
                backup_data = f.read()
            with open(backup_file, 'w') as f:
                f.write(backup_data)
        
        # 新しい設定を保存
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving config: {e}")
        return False

def login_required(f):
    """ログイン必須デコレーター"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def update_metrics():
    """メトリクスを更新（簡易版）"""
    try:
        # CPU使用率（簡易計算）
        with open('/proc/loadavg', 'r') as f:
            load = float(f.read().split()[0])
            metrics_data['cpu_usage'] = min(load * 25, 100)  # 簡易変換
        
        # メモリ使用率
        with open('/proc/meminfo', 'r') as f:
            lines = f.readlines()
            total = int(lines[0].split()[1])
            available = int(lines[2].split()[1])
            metrics_data['memory_usage'] = ((total - available) / total) * 100
    except:
        pass

# ルートハンドラー
@app.route('/')
@login_required
def index():
    """ダッシュボード"""
    return redirect(url_for('domains'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """ログインページ"""
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if username == ADMIN_USERNAME and password_hash == ADMIN_PASSWORD_HASH:
            session.permanent = True
            session['logged_in'] = True
            session['username'] = username
            return redirect(url_for('index'))
        else:
            return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """ログアウト"""
    session.clear()
    return redirect(url_for('login'))

@app.route('/domains')
@login_required
def domains():
    """ドメイン管理"""
    config = load_config()
    return render_template('domains.html', config=config)

@app.route('/devices')
@login_required
def devices():
    """デバイス管理"""
    config = load_config()
    return render_template('devices.html', config=config)

@app.route('/logs')
@login_required
def logs():
    """ログビューアー"""
    # 簡易ログ表示（最新50行）
    log_entries = []
    try:
        log_file = '/var/log/lpg-proxy.log'
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                lines = f.readlines()
                log_entries = lines[-50:]  # 最新50行
    except:
        pass
    
    return render_template('logs.html', logs=log_entries)

@app.route('/network')
@login_required
def network():
    """ネットワーク状態"""
    update_metrics()
    return render_template('network.html', metrics=metrics_data)

@app.route('/settings')
@login_required
def settings():
    """設定"""
    config = load_config()
    return render_template('settings.html', config=config)

# API エンドポイント
@app.route('/api/config', methods=['GET'])
@login_required
def api_get_config():
    """設定取得API"""
    config = load_config()
    return jsonify(config)

@app.route('/api/config', methods=['PUT'])
@login_required
def api_update_config():
    """設定更新API"""
    try:
        new_config = request.json
        if save_config(new_config):
            return jsonify({'status': 'success', 'message': 'Configuration saved'})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/domains', methods=['POST'])
@login_required
def api_add_domain():
    """ドメイン追加API"""
    try:
        data = request.json
        domain = data.get('domain')
        subnet = data.get('subnet')
        
        if not domain or not subnet:
            return jsonify({'status': 'error', 'message': 'Domain and subnet required'}), 400
        
        config = load_config()
        config['hostdomains'][domain] = subnet
        
        if domain not in config['hostingdevice']:
            config['hostingdevice'][domain] = {}
        
        if save_config(config):
            return jsonify({'status': 'success', 'message': 'Domain added'})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/devices', methods=['POST'])
@login_required
def api_add_device():
    """デバイスルール追加API"""
    try:
        data = request.json
        domain = data.get('domain')
        path = data.get('path', '')
        device_ip = data.get('deviceip')
        port = data.get('port')
        sitename = data.get('sitename')
        ips = data.get('ips', ['any'])
        
        if not all([domain, device_ip, port, sitename]):
            return jsonify({'status': 'error', 'message': 'Missing required fields'}), 400
        
        config = load_config()
        
        if domain not in config['hostingdevice']:
            config['hostingdevice'][domain] = {}
        
        config['hostingdevice'][domain][path] = {
            'deviceip': device_ip,
            'port': [int(port)] if isinstance(port, (str, int)) else port,
            'sitename': sitename,
            'ips': ips
        }
        
        if save_config(config):
            return jsonify({'status': 'success', 'message': 'Device rule added'})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/config/deploy', methods=['POST'])
@login_required
def api_deploy_config():
    """設定をデプロイ（プロキシ再起動）"""
    try:
        # TODO: 実際のプロキシサーバー再起動処理
        return jsonify({'status': 'success', 'message': 'Configuration deployed'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/system/status', methods=['GET'])
@login_required
def api_system_status():
    """システムステータス"""
    update_metrics()
    return jsonify({
        'status': 'healthy',
        'uptime': time.time(),
        'metrics': metrics_data
    })

if __name__ == '__main__':
    # テンプレートディレクトリ確認
    template_dir = os.path.join(os.path.dirname(__file__), 'templates')
    if not os.path.exists(template_dir):
        os.makedirs(template_dir)
    
    # 開発サーバー起動（本番環境ではgunicorn等を使用）
    app.run(host='0.0.0.0', port=8443, ssl_context='adhoc', debug=True)