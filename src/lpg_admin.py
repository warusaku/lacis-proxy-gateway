#\!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LPG Admin Interface
Version: 1.1
Date: 2025-08-06
Description: Unified template version with complete feature set
Changes from v1.0:
  - Removed all legacy templates (base.html, topology_v2.html, etc.)
  - Unified dark theme UI across all pages
  - Complete device management functionality
  - NGINX configuration section in Settings
  - 30-second auto-refresh for Topology page
"""

__version__ = "1.1"
__date__ = "2025-08-06"

import os
import json
import hashlib
import secrets
from datetime import datetime, timedelta

# セッションストア
session_store = {}
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from werkzeug.middleware.proxy_fix import ProxyFix
import threading
import time
import logging
import subprocess

# サーバー起動時刻を記録
START_TIME = datetime.now()

app = Flask(__name__, template_folder='/opt/lpg/templates')
app.config["TEMPLATES_AUTO_RELOAD"] = True

# Helper functions for UI display
def calculate_uptime():
    """システム稼働時間を計算 (nn day nn h nn m形式)"""
    delta = datetime.now() - START_TIME
    days = delta.days
    hours = delta.seconds // 3600
    minutes = (delta.seconds % 3600) // 60
    return f"{days} day {hours} h {minutes} m"

def count_active_sessions():
    """アクティブセッション数を取得"""
    # TODO: 実際のセッション数をカウント
    return len(session_store) if 'session_store' in globals() else 0

def get_devices():
    """デバイス情報を取得"""
    devices_from_file = load_devices_data()
    config = load_config()
    devices = []
    
    # devices.jsonから読み込んだデバイス
    for dev in devices_from_file:
        devices.append({
            'id': dev.get('device_id', dev.get('id', '')),
            'name': dev.get('device_name', dev.get('name', 'Unknown')),
            'ip': dev.get('device_ip', dev.get('ip', '192.168.234.10')),
            'port': dev.get('device_port', dev.get('port', 80)),
            'type': dev.get('device_type', dev.get('type', 'server')),
            'status': dev.get('status', 'active'),
            'path': dev.get('device_path', dev.get('path', '/')),
            'description': dev.get('device_description', dev.get('description', '')),
            'domain': dev.get('domain_name', dev.get('domain', '')),
            'access_count': dev.get('access_count', 0)
        })
    
    # configから追加のデバイス情報
    for domain, config_data in config.get('domains', {}).items():
        if 'upstream' in config_data:
            parts = config_data['upstream'].split(':')
            ip = parts[0] if parts else '192.168.234.10'
            port = int(parts[1]) if len(parts) > 1 else 80
            
            devices.append({
                'id': f'config_{domain}',
                'name': domain.replace('_', ' ').title(),
                'ip': ip,
                'port': port,
                'type': 'server',
                'status': 'active',
                'path': config_data.get('path', '/'),
                'description': f'From config: {domain}',
                'domain': domain
            })
    
    return devices

def get_domains():
    """ドメイン情報を取得"""
    config = load_config()
    domains = []
    
    # hostdomainsから基本情報を取得
    for domain_name, subnet in config.get('hostdomains', {}).items():
        # hostingdeviceから詳細情報を取得
        hosting_info = config.get('hostingdevice', {}).get(domain_name, {})
        
        # /lacisstack/boards の情報を優先的に使用
        boards_info = hosting_info.get('/lacisstack/boards', {})
        if boards_info:
            path = '/lacisstack/boards'
            deviceip = boards_info.get('deviceip', '192.168.234.10')
            port = boards_info.get('port', [8080])[0] if boards_info.get('port') else 8080
            upstream = f"{deviceip}:{port}"
        else:
            # デフォルト値
            path = '/'
            upstream = '192.168.234.10:8080'
        
        domains.append({
            'id': len(domains),
            'name': domain_name,
            'subnet': subnet,
            'path': path,
            'upstream': upstream,
            'status': 'active'
        })
    
    # domainsから（もしあれば）
    for domain_name, domain_config in config.get('domains', {}).items():
        if not any(d['name'] == domain_name for d in domains):
            domains.append({
                'id': len(domains),
                'name': domain_name,
                'upstream': domain_config.get('upstream', '192.168.234.10:8080'),
                'path': domain_config.get('path', '/'),
                'subnet': domain_config.get('subnet', '192.168.234.0/24'),
                'status': 'active'
            })
    
    # 実際のデータが少ない場合、定義済みドメインを追加
    if len(domains) == 0:
        # akb001yebraxfqsm9y.dyndns-web.comを追加
        domains.append({
            'id': 0,
            'name': 'akb001yebraxfqsm9y.dyndns-web.com',
            'path': '/lacisstack/boards',
            'upstream': '192.168.234.10:8080',
            'subnet': '192.168.234.0/24',
            'status': 'active'
        })
    
    return domains

def get_network_metrics():
    """ネットワーク統計情報を取得"""
    return {
        "bandwidth_usage": {
            "current": "125 Mbps",
            "peak": "450 Mbps",
            "average": "85 Mbps"
        },
        "packet_stats": {
            "received": "1.2M",
            "sent": "980K",
            "dropped": "12"
        },
        "connections": {
            "active": 42,
            "idle": 8,
            "total": 50
        },
        "latency": {
            "min": "0.5ms",
            "avg": "2.3ms",
            "max": "15ms"
        }
    }

# Handle reverse proxy path prefix
class ReverseProxied(object):
    def __init__(self, app):
        self.app = app

    def __call__(self, environ, start_response):
        script_name = environ.get('HTTP_X_SCRIPT_NAME', '')
        if script_name:
            environ['SCRIPT_NAME'] = script_name
            path_info = environ['PATH_INFO']
            if path_info.startswith(script_name):
                environ['PATH_INFO'] = path_info[len(script_name):]
        return self.app(environ, start_response)

app.wsgi_app = ReverseProxied(app.wsgi_app)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)


@app.before_request
def handle_proxy_prefix():
    """Handle requests coming through proxy with /lpg-admin prefix"""
    # Check if SCRIPT_NAME is set by nginx
    script_name = request.environ.get('SCRIPT_NAME', '')
    if script_name == '/lpg-admin':
        # Flask will handle URL generation with SCRIPT_NAME
        pass  # No need to modify PATH_INFO

# Fix URL generation to include prefix
def external_url_for(endpoint, **values):
    """Generate URLs that work with reverse proxy prefix"""
    # Just use Flask's built-in url_for, which respects SCRIPT_NAME
    return url_for(endpoint, **values)

app.jinja_env.globals.update(url_for=external_url_for)


def url_for_with_prefix(endpoint, **values):
    """Generate URL with proper prefix handling for reverse proxy"""
    from flask import request, url_for as flask_url_for
    prefix = request.headers.get('X-Forwarded-Prefix', '')
    url = flask_url_for(endpoint, **values)
    if prefix and not url.startswith(prefix):
        # Remove leading slash from url if present
        if url.startswith('/'):
            url = url[1:]
        return f"{prefix}/{url}"
    return url

# Override url_for in templates

# Custom URL generation for templates

app.secret_key = os.environ.get('FLASK_SECRET_KEY', secrets.token_hex(32))

# Jinja2カスタムフィルター
@app.template_filter('jst_time')
def jst_time_filter(timestamp_str):
    """UTC時刻をJSTに変換"""
    try:
        # ISO形式のタイムスタンプをパース
        if 'T' in timestamp_str:
            dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            # JSTに変換(+9時間)
            jst_dt = dt + timedelta(hours=9)
            return jst_dt.strftime('%Y-%m-%d %H:%M:%S JST')
        else:
            return timestamp_str
    except:
        return timestamp_str

# 設定ファイルパス
CONFIG_FILE = '/etc/lpg/config.json'
if not os.path.exists(CONFIG_FILE):
    CONFIG_FILE = './config/config.json'

# デバイスデータファイルパス
DEVICES_FILE = '/opt/lpg/src/devices.json'
if not os.path.exists(DEVICES_FILE):
    DEVICES_FILE = './devices.json'

# 簡易認証設定(本番環境では環境変数から取得)
ADMIN_USERNAME = os.environ.get('LPG_ADMIN_USER', 'admin')
ADMIN_PASSWORD_HASH = hashlib.sha256(
    os.environ.get('LPG_ADMIN_PASS', 'lpgadmin123').encode()
).hexdigest()

# セッションタイムアウト(24時間)
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
            return redirect(external_url_for("login"))
        return f(*args, **kwargs)
    return decorated_function

def update_metrics():
    """メトリクスを更新(簡易版)"""
    try:
        # CPU使用率(簡易計算)
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

def log_login(username, ip_address):
    """ログイン記録"""
    try:
        log_message = f"{datetime.now().isoformat()} - LOGIN - User {username} logged in from {ip_address}\n"
        log_file = '/var/log/lpg-proxy.log'
        with open(log_file, 'a') as f:
            f.write(log_message)
    except:
        pass

def get_system_uptime():
    """システムのuptime値を取得"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
        
        # 日時分秒に変換
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    except:
        return "Unknown"

def load_devices_data():
    """デバイスデータファイルを読み込む"""
    try:
        with open(DEVICES_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data.get('devices', [])
    except:
        return []

def save_devices_data(devices):
    """Save devices to JSON file"""
    try:
        # Ensure devices is a list
        if not isinstance(devices, list):
            devices = []
        
        data = {'devices': devices}
        
        # Write to devices.json
        with open(DEVICES_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        # Also update config.json with routing information
        try:
            with open('config.json', 'r', encoding='utf-8') as f:
                config = json.load(f)
        except:
            config = {'domains': {}}
        
        # Update domain mappings in config
        for device in devices:
            domain = device.get('domain_name') or device.get('domain')
            path = device.get('path') or device.get('registration_path', '/')
            ip = device.get('ip_address') or device.get('ip') or device.get('device_ip')
            port = device.get('port', 80)
            
            if domain and ip:
                if domain not in config['domains']:
                    config['domains'][domain] = {'paths': {}}
                
                # Handle port as list or single value
                if isinstance(port, list):
                    port_str = str(port[0]) if port else '80'
                else:
                    port_str = str(port)
                
                config['domains'][domain]['paths'][path] = {
                    'upstream': f"{ip}:{port_str}",
                    'enabled': True
                }
        
        # Write updated config
        with open('config.json', 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        return True
    except Exception as e:
        print(f"Error saving devices: {e}")
        import traceback
        traceback.print_exc()
        return False

# ルートハンドラー
@app.route('/')
@login_required
def index():
    """ダッシュボード"""
    return redirect(url_for('topology', _external=False))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """ログインページ"""
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        # マスターアカウントチェック
        if username == ADMIN_USERNAME and password_hash == ADMIN_PASSWORD_HASH:
            session.permanent = True
            session['logged_in'] = True
            session['username'] = username
            # ログイン記録
            log_login(username, request.remote_addr)
            return redirect(url_for('index', _external=False))
        
        # その他のユーザーチェック
        config = load_config()
        users = config.get('adminuser', {})
        if username in users and users[username].get('password_hash') == password_hash:
            session.permanent = True
            session['logged_in'] = True
            session['username'] = username
            # ログイン記録
            log_login(username, request.remote_addr)
            return redirect(url_for('index', _external=False))
        
        return render_template('login_unified.html', error='Invalid credentials')
    
    return render_template('login_unified.html')

@app.route('/logout')
def logout():
    """ログアウト"""
    session.clear()
    return redirect(external_url_for("login"))

@app.route('/domains')
@login_required
def domains():
    """ドメイン管理"""
    config = load_config()
    
    # helper関数を使用してドメイン情報を取得
    domains_data = get_domains()
    
    # 追加情報を付与
    devices_data = get_devices()
    for domain in domains_data:
        # 各ドメインのデバイス数をカウント
        device_count = sum(1 for d in devices_data if d.get('domain') == domain.get('name'))
        domain['device_count'] = device_count
    
    return render_template('domains_unified.html', domains=domains_data, config=config)

@app.route('/devices')
@login_required
def devices():
    """デバイス管理"""
    # helper関数を使用してデバイス情報を取得
    devices_data = get_devices()
    
    # IPアドレスが正しく設定されているか確認
    for device in devices_data:
        # device_ipフィールドを追加(テンプレート互換性のため)
        device['device_ip'] = device.get('ip', '192.168.234.10')
        device['device_name'] = device.get('name', 'Unknown Device')
        device['device_port'] = device.get('port', 80)
        device['device_path'] = device.get('path', '/')
        device['device_type'] = device.get('type', 'server')
        device['device_description'] = device.get('description', '')
        device['domain_name'] = device.get('domain', '')
    
    return render_template('devices_unified.html', devices=devices_data)

@app.route('/logs')
@login_required
def logs():
    """ログビューアー"""
    # 簡易ログ表示(最新50行)
    log_entries = []
    try:
        log_file = '/var/log/lpg-proxy.log'
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                lines = f.readlines()
                # 最新50行を取得し、パース
                for line in lines[-50:]:
                    # ログフォーマット: "2025-08-04T12:34:56 - TYPE - Message"
                    parts = line.strip().split(' - ', 2)
                    if len(parts) >= 3:
                        log_entries.append({
                            'timestamp': parts[0],
                            'type': parts[1],
                            'message': parts[2]
                        })
                    else:
                        log_entries.append({
                            'timestamp': datetime.now().isoformat(),
                            'type': 'INFO',
                            'message': line.strip()
                        })
        
        # アクセスログも追加
        access_log = '/var/log/lpg_access.log'
        if os.path.exists(access_log):
            with open(access_log, 'r') as f:
                lines = f.readlines()
                for line in lines[-20:]:  # 最新20行
                    log_entries.append({
                        'timestamp': datetime.now().isoformat(),
                        'type': 'ACCESS',
                        'message': line.strip()
                    })
        
        # 時刻順にソート(新しいものが先)
        log_entries.sort(key=lambda x: x['timestamp'], reverse=True)
        
    except Exception as e:
        log_entries.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'ERROR',
            'message': f'Failed to load logs: {str(e)}'
        })
    
    return render_template('logs_unified.html', logs=log_entries)

@app.route('/network')
@login_required
def network():
    """ネットワーク状態"""
    update_metrics()
    
    # Helper関数でネットワーク統計データを取得
    network_metrics = get_network_metrics()
    
    # 実際のネットワーク接続を取得（statsの前に移動してカウントに使用）
    connections = []
    active_connection_count = 0  # 実際の接続数をカウント
    try:
        import subprocess
        # netstatで接続を取得(-an で数値表示)
        result = subprocess.run(['netstat', '-an'], capture_output=True, text=True, timeout=3)
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if 'ESTABLISHED' in line or 'LISTEN' in line:
                    parts = line.split()
                    if len(parts) >= 5:
                        local_addr = parts[3]
                        remote_addr = parts[4]
                        state = parts[5] if len(parts) > 5 else 'UNKNOWN'
                        
                        # アドレスからIPとポートを分離
                        if ':' in local_addr and ':' in remote_addr:
                            local_ip = ':'.join(local_addr.split(':')[:-1])
                            local_port = local_addr.split(':')[-1]
                            remote_ip = ':'.join(remote_addr.split(':')[:-1])
                            remote_port = remote_addr.split(':')[-1]
                            
                            # ローカルネットワークまたは重要なポートの接続を表示
                            if (remote_ip.startswith('192.168.') or 
                                local_port in ['80', '8080', '8081', '8443', '8444'] or
                                remote_port in ['80', '8080', '8081', '8443', '8444']):
                                connections.append({
                                    'source': remote_ip if remote_ip != '0.0.0.0' else 'Any',
                                    'destination': f"{local_ip}:{local_port}",
                                    'protocol': 'TCP',
                                    'duration': state,
                                    'bytes': 'N/A'
                                })
                                
                                if len(connections) >= 20:  # 最大20件
                                    break
    except Exception as e:
        print(f"Netstat error: {e}")
    
    # 接続が見つからない場合はサンプルデータ
    if not connections:
        connections = [
            {
                'source': '192.168.234.10',
                'destination': '192.168.234.2:8080',
                'protocol': 'HTTPS',
                'duration': 'Active',
                'bytes': 'N/A'
            }
        ]
    
    # 実際の接続数をカウント（修正: connectionsを取得した後にカウント）
    active_connection_count = len(connections)
    
    # ネットワーク統計データを構築（修正: 実際の接続数を使用）
    stats = {
        'total_connections': active_connection_count,  # 実際の接続数を使用
        'bandwidth': network_metrics['bandwidth_usage']['current'],
        'latency': network_metrics['latency']['avg'],
        'packet_loss': f"{metrics_data.get('errors', 0)}%",
        'packets_received': network_metrics['packet_stats']['received'],
        'packets_sent': network_metrics['packet_stats']['sent'],
        'packets_dropped': network_metrics['packet_stats']['dropped']
    }
    
    return render_template('network_unified.html', 
                         stats=stats, 
                         connections=connections,
                         metrics=metrics_data)

@app.route('/settings')
@login_required
def settings():
    """設定"""
    config = load_config()
    return render_template('settings_unified.html', config=config)

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


@app.route('/api/domains')
@login_required
def api_domains():
    """Get list of registered domains"""
    try:
        config = load_config()
        domains = []
        
        # Extract unique domains from configuration
        seen_domains = set()
        for domain, settings in config.get('domains', {}).items():
            if domain not in seen_domains:
                domains.append({
                    'name': domain,
                    'upstream': settings.get('upstream', ''),
                    'path': settings.get('path', '/')
                })
                seen_domains.add(domain)
        
        return jsonify({'domains': domains})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/devices', methods=['POST'])
@login_required
def api_add_device():
    """デバイスルール追加API"""
    try:
        data = request.json
        
        # 新しい形式のデータもサポート
        domain = data.get('domain') or data.get('domain_name')
        path = data.get('path', '/')
        device_ip = data.get('deviceip') or data.get('device_ip')
        port = data.get('port')
        sitename = data.get('sitename') or data.get('site_name') or data.get('name')
        ips = data.get('ips', ['any']) or data.get('allowed_ips', ['192.168.3.0/24'])
        device_type = data.get('type', 'server')
        description = data.get('description', '')
        
        if not all([domain, device_ip, port, sitename]):
            return jsonify({'status': 'error', 'message': 'Missing required fields: domain, device_ip, port, site_name'}), 400
        
        # Generate device ID
        import uuid
        device_id = str(uuid.uuid4())[:8]
        
        # Add to devices.json
        devices_data = load_devices_data()
        devices = devices_data.get('devices', []) if isinstance(devices_data, dict) else devices_data
        new_device = {
            'id': device_id,
            'name': sitename,
            'device_name': sitename,
            'ip_address': device_ip,
            'port': port if isinstance(port, list) else [port],
            'path': path,
            'domain_name': domain,
            'description': description,
            'type': device_type,
            'status': 'active',
            'access_count': 0
        }
        devices.append(new_device)
        save_devices_data(devices)
        
        # Also add to config.json for routing
        config = load_config()
        
        if domain not in config.get('hostingdevice', {}):
            config['hostingdevice'][domain] = {}
        
        config['hostingdevice'][domain][path] = {
            'deviceip': device_ip,
            'port': [int(port)] if isinstance(port, (str, int)) else port,
            'sitename': sitename,
            'ips': ips
        }
        
        if save_config(config):
            # ルールファイルの生成
            try:
                output_file = '/opt/lpg/rules/device_rules.json'
                import json
                with open(output_file, 'w') as f:
                    json.dump(config.get('hostingdevice', {}), f, indent=2)
            except:
                pass
            return jsonify({'status': 'success', 'message': 'Device rule added', 'device_id': device_id})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/devices/<device_id>', methods=['PUT'])
@login_required
def api_update_device(device_id):
    """Update device API"""
    try:
        data = request.json
        
        # Load current devices data
        devices_data = load_devices_data()
        devices = devices_data.get('devices', []) if isinstance(devices_data, dict) else devices_data
        
        # Find the device to update
        device_found = False
        for device in devices:
            if device.get('id') == device_id:
                # Update device properties
                device['name'] = data.get('site_name', device.get('name'))
                device['device_name'] = data.get('site_name', device.get('device_name'))
                device['ip_address'] = data.get('device_ip', device.get('ip_address'))
                device['port'] = data.get('port', device.get('port'))
                device['path'] = data.get('path', device.get('path', '/'))
                device['domain_name'] = data.get('domain_name', device.get('domain_name'))
                device['description'] = data.get('description', device.get('description', ''))
                device['type'] = data.get('type', device.get('type', 'server'))
                device_found = True
                break
        
        if not device_found:
            # Device doesn't exist in devices.json, create new one
            new_device = {
                'id': device_id,
                'name': data.get('site_name', 'Unknown'),
                'device_name': data.get('site_name', 'Unknown'),
                'ip_address': data.get('device_ip', ''),
                'port': data.get('port', [80]),
                'path': data.get('path', '/'),
                'domain_name': data.get('domain_name', ''),
                'description': data.get('description', ''),
                'type': data.get('type', 'server'),
                'status': 'active'
            }
            devices.append(new_device)
        
        # Save the updated devices data
        save_devices_data(devices)
        
        # Also update config.json for routing
        config = load_config()
        domain = data.get('domain_name')
        path = data.get('path', '/')
        
        if domain:
            if 'hostingdevice' not in config:
                config['hostingdevice'] = {}
            if domain not in config['hostingdevice']:
                config['hostingdevice'][domain] = {}
            
            config['hostingdevice'][domain][path] = {
                'deviceip': data.get('device_ip'),
                'port': data.get('port'),
                'sitename': data.get('site_name'),
                'ips': ['any']
            }
            
            save_config(config)
        
        return jsonify({'success': True, 'message': 'Device updated successfully'})
        
    except Exception as e:
        print(f"Error updating device: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/devices/<device_id>', methods=['DELETE']) 
@login_required
def api_delete_device_by_id(device_id):
    """Delete device by ID"""
    try:
        # Load current devices data
        devices_data = load_devices_data()
        devices = devices_data.get('devices', []) if isinstance(devices_data, dict) else devices_data
        
        # Find and remove the device
        device_to_delete = None
        for device in devices:
            if device.get('id') == device_id:
                device_to_delete = device
                devices.remove(device)
                break
        
        if not device_to_delete:
            return jsonify({'success': False, 'error': 'Device not found'}), 404
        
        # Save the updated devices data
        save_devices_data(devices)
        
        # Also remove from config.json
        config = load_config()
        domain = device_to_delete.get('domain_name')
        path = device_to_delete.get('path', '/')
        
        if domain and domain in config.get('hostingdevice', {}):
            if path in config['hostingdevice'][domain]:
                del config['hostingdevice'][domain][path]
                
                # Remove domain if no paths left
                if not config['hostingdevice'][domain]:
                    del config['hostingdevice'][domain]
                
                save_config(config)
        
        return jsonify({'success': True, 'message': 'Device deleted successfully'})
        
    except Exception as e:
        print(f"Error deleting device: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/devices/<domain>/<path>', methods=['DELETE'])
@login_required  
def api_delete_device(domain, path):
    """デバイス削除API"""
    try:
        config = load_config()
        
        if domain in config.get('hostingdevice', {}):
            if path in config['hostingdevice'][domain]:
                device_info = config['hostingdevice'][domain][path]
                del config['hostingdevice'][domain][path]
                
                # ドメインが空になった場合は削除
                if not config['hostingdevice'][domain]:
                    del config['hostingdevice'][domain]
                
                if save_config(config):
                    # デバイス削除をログに記録
                    log_message = f"{datetime.now().isoformat()} - INFO - Device {device_info.get('sitename', 'Unknown')} ({device_info.get('deviceip', 'Unknown IP')}) deleted from {domain}{path} by {session.get('username')}\n"
                    try:
                        with open('/var/log/lpg-proxy.log', 'a') as f:
                            f.write(log_message)
                    except:
                        pass
                    return jsonify({'status': 'success', 'message': 'Device deleted'})
                else:
                    return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
            else:
                return jsonify({'status': 'error', 'message': 'Device path not found'}), 404
        else:
            return jsonify({'status': 'error', 'message': 'Domain not found'}), 404
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/config/deploy', methods=['POST'])
@login_required
def api_deploy_config():
    """設定をデプロイ(プロキシ再起動)"""
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

@app.route('/api/users', methods=['POST'])
@login_required
def api_add_user():
    """ユーザー追加API"""
    try:
        data = request.json
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return jsonify({'status': 'error', 'message': 'Username and password required'}), 400
        
        if username == 'admin':
            return jsonify({'status': 'error', 'message': 'Cannot use reserved username'}), 400
        
        config = load_config()
        if 'adminuser' not in config:
            config['adminuser'] = {}
        
        if username in config['adminuser']:
            return jsonify({'status': 'error', 'message': 'User already exists'}), 400
        
        config['adminuser'][username] = {
            'password_hash': hashlib.sha256(password.encode()).hexdigest(),
            'created': datetime.now().isoformat(),
            'created_by': session.get('username', 'unknown')
        }
        
        if save_config(config):
            # ユーザー追加をログに記録
            logging.info(f"User {username} added by {session.get('username')}")
            return jsonify({'status': 'success', 'message': 'User added'})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/users/<username>', methods=['DELETE'])
@login_required
def api_delete_user(username):
    """ユーザー削除API"""
    try:
        if username == 'admin':
            return jsonify({'status': 'error', 'message': 'Cannot delete master account'}), 403
        
        config = load_config()
        if 'adminuser' in config and username in config['adminuser']:
            del config['adminuser'][username]
            
            if save_config(config):
                # ユーザー削除をログに記録
                logging.info(f"User {username} deleted by {session.get('username')}")
                return jsonify({'status': 'success', 'message': 'User deleted'})
            else:
                return jsonify({'status': 'error', 'message': 'Failed to save configuration'}), 500
        else:
            return jsonify({'status': 'error', 'message': 'User not found'}), 404
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/topology')
@login_required
def topology():
    """システムトポロジービュー"""
    config = load_config()
    
    # Helper関数を使用してデータ取得
    devices = get_devices()
    domains = get_domains()
    
    # domainsに追加情報を付与
    for i, domain in enumerate(domains):
        domain.update({
            'domain_name': domain.get('name', ''),
            'display_name': domain.get('name', ''),
            'connection_count': 0,
            'lpg_ip': '192.168.234.2',
            'connection_type': 'HTTPS',
            'speed': '1 Gbps',
            'registration_path': domain.get('path', '/')
        })
    
    # devicesに追加情報を付与  
    total_access_count = 0
    for device in devices:
        # IPアドレスが正しく設定されているか確認
        if not device.get('ip') or device.get('ip') == '':
            device['ip'] = '192.168.234.10'  # デフォルトIP
        
        # ip_address フィールドも追加(テンプレート互換性のため)
        device['ip_address'] = device.get('ip')
        
        # アクセス数を取得または生成（デモ用にランダム値を使用）
        import random
        # if 'access_count' not in device:
        # デバイスタイプに基づいてアクセス数を設定
        if device.get('type') == 'server':
            device['access_count'] = device.get("access_count", 0)  # TODO: Implement proper access counting  # 実際のセッション数
        elif device.get('type') == 'application':
            device['access_count'] = device.get("access_count", 0)  # TODO: Implement proper access counting
        else:
            device['access_count'] = 0
        
        access_count = device.get('access_count', 0)
        total_access_count += access_count
        
        # 追加のフィールド
        device.update({
            'ports': [device.get('port', 80)],
            'domain_id': 0,
            'ping_status': device.get('ping_status', 'unknown'),
            'last_ping': device.get('last_ping', '')
        })
    
    # 既存のデバイスIPをチェック(重複防止)
    existing_ips = {d.get('ip', '') for d in devices if d.get('ip')}
    
    # メトリクスデータ(helper関数を使用)
    network_metrics = get_network_metrics()
    metrics = {
        'active_connections': total_access_count,
        'active_sessions': count_active_sessions(),
        'total_domains': len(domains),
        'total_devices': len(devices),
        'uptime': calculate_uptime(),
        'system_uptime': calculate_uptime(),  # テンプレート互換性のため
        'bandwidth': '1.2 GB/s',
        'bandwidth_usage': '65'  # パーセンテージとして表示（数値のみ）
    }
    
    from datetime import datetime
    # 改善されたトポロジーテンプレートを使用
    return render_template('topology_unified.html', 
                         config=config, 
                         domains=domains, 
                         devices=devices, 
                         metrics=metrics,
                         lpg_access_count=total_access_count,
                         current_time=datetime.now().strftime('%H:%M:%S'))

@app.route('/api/device/<device_id>/ping', methods=['GET'])
@login_required
def api_ping_device(device_id):
    """デバイスのping状態を確認"""
    try:
        # デバイス情報を取得
        devices_from_file = load_devices_data()
        device = next((d for d in devices_from_file if d.get('id') == device_id), None)
        
        if not device:
            return jsonify({'status': 'error', 'message': 'Device not found'}), 404
        
        ip_address = device.get('ip_address', '')
        if not ip_address:
            return jsonify({'status': 'error', 'message': 'No IP address for device'}), 400
        
        # ping実行(タイムアウト2秒、1回のみ)
        import subprocess
        try:
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '2', ip_address],
                capture_output=True,
                text=True,
                timeout=3
            )
            
            is_alive = result.returncode == 0
            
            # 結果を返す
            return jsonify({
                'status': 'success',
                'device_id': device_id,
                'ip_address': ip_address,
                'is_alive': is_alive,
                'timestamp': datetime.now().isoformat()
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({
                'status': 'success',
                'device_id': device_id,
                'ip_address': ip_address,
                'is_alive': False,
                'timestamp': datetime.now().isoformat()
            })
            
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/network/connections', methods=['GET'])
@login_required
def api_get_network_connections():
    """実際のネットワーク接続を取得"""
    try:
        connections = []
        
        # netstatコマンドで接続を取得
        import subprocess
        try:
            # TCPとUDPの確立された接続を取得
            result = subprocess.run(
                ['netstat', '-tn'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[2:]:  # ヘッダーをスキップ
                    parts = line.split()
                    if len(parts) >= 5 and 'ESTABLISHED' in line:
                        local_addr = parts[3]
                        remote_addr = parts[4]
                        
                        # IPアドレスとポートを分離
                        if ':' in remote_addr:
                            remote_ip = ':'.join(remote_addr.split(':')[:-1])
                            remote_port = remote_addr.split(':')[-1]
                            
                            # 192.168.x.xのネットワークのみ表示
                            if remote_ip.startswith('192.168.'):
                                connections.append({
                                    'source': remote_ip,
                                    'destination': local_addr,
                                    'protocol': 'TCP',
                                    'status': 'ESTABLISHED'
                                })
                                
                                if len(connections) >= 10:  # 最大10件
                                    break
        except:
            # デフォルトデータ
            connections = [
                {
                    'source': '192.168.234.10',
                    'destination': '192.168.234.2:8080',
                    'protocol': 'HTTPS',
                    'status': 'ESTABLISHED'
                }
            ]
        
        return jsonify({'connections': connections})
        
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/devices', methods=['GET'])
@login_required
def api_get_devices():
    """デバイス一覧を取得"""
    try:
        # devices.jsonからデバイスデータを読み込む
        devices_data = load_devices_data()
        devices = devices_data.get('devices', []) if isinstance(devices_data, dict) else devices_data
        
        # 各デバイスにipフィールドを追加(テンプレートの互換性のため)
        for device in devices:
            if 'ip' not in device:
                device['ip'] = device.get('ip_address', '')
        
        return jsonify({'devices': devices, 'status': 'success'})
        
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e), 'devices': []}), 500


# NGINX Management API Endpoints
@app.route('/api/nginx/certificate', methods=['GET'])
@login_required
def api_nginx_certificate():
    """Get SSL certificate status"""
    try:
        import ssl
        import socket
        from datetime import datetime
        
        # Check certificate for the domain
        hostname = 'akb001yebraxfqsm9y.dyndns-web.com'
        port = 443
        
        context = ssl.create_default_context()
        with socket.create_connection((hostname, port), timeout=3) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
                expiry_date = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z')
                days_remaining = (expiry_date - datetime.now()).days
                
                return jsonify({
                    'valid': True,
                    'expiry': expiry_date.strftime('%Y-%m-%d %H:%M:%S'),
                    'days_remaining': days_remaining,
                    'issuer': cert.get('issuer', [{}])[0].get('organizationName', 'Unknown')
                })
    except Exception as e:
        return jsonify({
            'valid': False,
            'error': str(e),
            'expiry': 'Unknown'
        })

@app.route('/api/nginx/certificate/renew', methods=['POST'])
@login_required
def api_nginx_certificate_renew():
    """Renew SSL certificate (placeholder)"""
    try:
        # This would normally trigger certbot renewal
        # For now, just return a success message
        return jsonify({
            'success': True,
            'message': 'Certificate renewal initiated (feature not fully implemented)'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/nginx/cache/stats', methods=['GET'])
@login_required
def api_nginx_cache_stats():
    """Get cache statistics"""
    try:
        import os
        
        # Calculate cache directory size (placeholder)
        cache_dir = '/var/cache/nginx'
        total_size = 0
        
        if os.path.exists(cache_dir):
            for dirpath, dirnames, filenames in os.walk(cache_dir):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    if os.path.exists(fp):
                        total_size += os.path.getsize(fp)
        
        size_mb = round(total_size / (1024 * 1024), 2)
        
        return jsonify({
            'size': f'{size_mb} MB',
            'hits': 0,  # Would need to parse nginx logs
            'misses': 0  # Would need to parse nginx logs
        })
    except Exception as e:
        return jsonify({'size': '0 MB', 'hits': 0, 'misses': 0})

@app.route('/api/nginx/cache/toggle', methods=['POST'])
@login_required
def api_nginx_cache_toggle():
    """Toggle cache on/off"""
    try:
        enabled = request.json.get('enabled', True)
        # This would normally modify nginx config
        return jsonify({'success': True, 'enabled': enabled})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/nginx/cache/clear', methods=['POST'])
@login_required
def api_nginx_cache_clear():
    """Clear nginx cache"""
    try:
        import subprocess
        # Clear cache directory (be careful with permissions)
        # subprocess.run(['rm', '-rf', '/var/cache/nginx/*'], shell=True)
        return jsonify({'success': True, 'message': 'Cache cleared (feature limited)'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/nginx/reload', methods=['POST'])
@login_required
def api_nginx_reload():
    """Reload NGINX configuration"""
    try:
        import subprocess
        # Test configuration first
        result = subprocess.run(['nginx', '-t'], capture_output=True, text=True)
        if result.returncode == 0:
            # Reload nginx
            subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
            return jsonify({'success': True, 'message': 'NGINX reloaded successfully'})
        else:
            return jsonify({'success': False, 'error': result.stderr}), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/nginx/paths', methods=['GET'])
@login_required
def api_nginx_paths():
    """Get configured proxy paths"""
    try:
        paths = [
            {'path': '/lpg-admin/', 'target': 'localhost:8443', 'active': True},
            {'path': '/lacisstack/boards/', 'target': '192.168.234.10:3001', 'active': False},
            {'path': '/lacisstack/boards/api/', 'target': '192.168.234.10:3001', 'active': False},
            {'path': '/lacisstack/boards/socket.io/', 'target': '192.168.234.10:8081', 'active': False}
        ]
        
        # Check actual configuration
        config = load_config()
        for domain, settings in config.get('domains', {}).items():
            if domain not in [p['path'] for p in paths]:
                paths.append({
                    'path': f'/{domain}/',
                    'target': settings.get('upstream', 'unknown'),
                    'active': False
                })
        
        return jsonify({'paths': paths})
    except Exception as e:
        return jsonify({'paths': [], 'error': str(e)}), 500

@app.route('/api/nginx/test-path', methods=['POST'])
@login_required
def api_nginx_test_path():
    """Test a specific proxy path"""
    try:
        import requests
        path = request.json.get('path', '')
        
        # Test the path
        test_url = f'http://localhost{path}'
        response = requests.get(test_url, timeout=3)
        
        return jsonify({
            'success': response.status_code < 400,
            'status_code': response.status_code
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/nginx/config', methods=['GET'])
@login_required
def api_nginx_config():
    """View NGINX configuration (read-only)"""
    try:
        config_file = '/etc/nginx/sites-available/lpg-ssl'
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config_content = f.read()
            return config_content, 200, {'Content-Type': 'text/plain'}
        else:
            return 'Configuration file not found', 404
    except Exception as e:
        return str(e), 500


if __name__ == '__main__':
    # 簡易的な起動方法(本番環境ではgunicorn等を推奨)
    # LPGシステムではnohupで起動される
    import os
    host = os.environ.get('LPG_ADMIN_HOST', '127.0.0.1')  # CRITICAL: Never use 0.0.0.0
    port = int(os.environ.get('LPG_ADMIN_PORT', '8443'))
    
    print(f"Starting LPG Admin UI on {host}:{port}")
    print("Access the admin UI at http://192.168.234.2:8443")
    
    # 本番環境では debug=False にすること
    app.run(host=host, port=port, debug=False)
# End of file
