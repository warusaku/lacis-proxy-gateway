#!/bin/bash

# LPG管理UIトポロジーページ修正スクリプト
# 作成日: 2025-08-04
# 目的: topology_v2.htmlのJinja2テンプレートエラーを修正

echo "=== LPG管理UIトポロジーページ修正 ==="
echo ""

# SSHで接続してトポロジーテンプレートを修正
expect << 'EOF'
set timeout 30

spawn ssh -o StrictHostKeyChecking=no root@192.168.234.2

expect {
    "password:" {
        send "orangepi\r"
    }
    timeout {
        puts "SSH接続タイムアウト"
        exit 1
    }
}

expect "root@"

# 既存のテンプレートをバックアップ
send "cd /opt/lpg/src/templates\r"
expect "root@"

send "cp topology_v2.html topology_v2.html.bak.$(date +%Y%m%d_%H%M%S)\r"
expect "root@"

# 修正済みテンプレートをアップロード
send "cat > topology_fixed.html << 'TEMPLATE_EOF'\r"

# テンプレート内容を送信（devices_by_ip問題を修正）
send {{% extends "base_dark.html" %}

{% block title %}トポロジー - LacisProxyGateway{% endblock %}

{% block content %}
<div class="container-fluid">
    <h1 class="mb-4">
        <i class="bi bi-diagram-3"></i> ネットワークトポロジー
    </h1>

    <!-- ネットワーク図 -->
    <div class="card mb-4">
        <div class="card-header">
            <h4><i class="bi bi-diagram-2"></i> ネットワーク構成</h4>
        </div>
        <div class="card-body" style="overflow: auto; max-height: 600px;">
            <svg id="topology-svg" viewBox="0 0 1200 800" style="width: 100%; min-width: 1000px;">
                <!-- 背景グリッド -->
                <defs>
                    <pattern id="grid" width="50" height="50" patternUnits="userSpaceOnUse">
                        <path d="M 50 0 L 0 0 0 50" fill="none" stroke="#21262d" stroke-width="1"/>
                    </pattern>
                </defs>
                <rect width="100%" height="100%" fill="#0d1117"/>
                <rect width="100%" height="100%" fill="url(#grid)"/>
                
                <!-- インターネット -->
                <g transform="translate(600, 50)">
                    <circle cx="0" cy="0" r="40" fill="#1f6feb" stroke="#58a6ff" stroke-width="2"/>
                    <text x="0" y="5" text-anchor="middle" fill="#ffffff" font-size="14" font-weight="bold">Internet</text>
                </g>
                
                <!-- LPG（中央配置） -->
                <g transform="translate(600, 250)">
                    <rect x="-80" y="-40" width="160" height="80" rx="10" fill="#238636" stroke="#2ea043" stroke-width="2"/>
                    <text x="0" y="0" text-anchor="middle" fill="#ffffff" font-size="16" font-weight="bold">
                        <tspan x="0" dy="-10">LPG</tspan>
                        <tspan x="0" dy="20" font-size="12">192.168.234.2</tspan>
                        <tspan x="0" dy="15" font-size="10">
                            <tspan fill="#58a6ff">● 稼働中</tspan>
                        </tspan>
                    </text>
                </g>
                
                <!-- インターネットからLPGへの接続線 -->
                <line x1="600" y1="90" x2="600" y2="210" stroke="#58a6ff" stroke-width="3"/>
                
                <!-- ドメイン表示 -->
                {% for domain in domains %}
                <g transform="translate(300, {{ 150 + loop.index0 * 80 }})">
                    <rect x="-100" y="-25" width="200" height="50" rx="5" fill="#161b22" stroke="#30363d" stroke-width="1"/>
                    <text x="0" y="0" text-anchor="middle" fill="#c9d1d9" font-size="11">
                        <tspan x="0" dy="-5">{{ domain.domain_name[:25] }}</tspan>
                        <tspan x="0" dy="15" fill="#8b949e" font-size="9">{{ domain.allowed_subnets[0] if domain.allowed_subnets else 'any' }}</tspan>
                    </text>
                    <line x1="100" y1="0" x2="220" y2="{{ 250 - 150 - loop.index0 * 80 }}" 
                          stroke="#30363d" stroke-width="1" stroke-dasharray="3,3"/>
                </g>
                {% endfor %}
                
                <!-- デバイス表示（シンプル版） -->
                {% for device in devices %}
                <g transform="translate(900, {{ 150 + loop.index0 * 100 }})">
                    <rect x="-100" y="-40" width="200" height="80" rx="5" fill="#21262d" stroke="#f85149" stroke-width="1"/>
                    <text x="0" y="-20" text-anchor="middle" fill="#c9d1d9" font-size="12" font-weight="bold">
                        {{ device.ip_address }}
                    </text>
                    <text x="0" y="0" text-anchor="middle" fill="#8b949e" font-size="10">
                        <tspan x="0" dy="12">{{ device.device_name[:20] }}</tspan>
                    </text>
                    <circle cx="85" cy="-25" r="5" fill="{{ '#2ea043' if device.status == 'active' else '#f85149' }}"/>
                    <line x1="-100" y1="0" x2="-220" y2="{{ 250 - 150 - loop.index0 * 100 }}" 
                          stroke="#30363d" stroke-width="2"/>
                </g>
                {% endfor %}
            </svg>
        </div>
    </div>

    <!-- 詳細情報テーブル -->
    <div class="row">
        <!-- LPGステータス -->
        <div class="col-md-12 mb-3">
            <div class="card">
                <div class="card-header">
                    <h5><i class="bi bi-hdd-network"></i> LPGステータス</h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-3">
                            <h6>稼働状態</h6>
                            <span class="badge bg-success fs-6">● 稼働中</span>
                        </div>
                        <div class="col-md-3">
                            <h6>IPアドレス</h6>
                            <span class="text-info">192.168.234.2</span>
                        </div>
                        <div class="col-md-3">
                            <h6>接続デバイス数</h6>
                            <span class="badge bg-primary fs-6">{{ devices|length }} サービス</span>
                        </div>
                        <div class="col-md-3">
                            <h6>アップタイム</h6>
                            <span class="text-success">{{ metrics.uptime|default('N/A') }}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- デバイス詳細 -->
        <div class="col-md-12">
            <div class="card">
                <div class="card-header">
                    <h5><i class="bi bi-server"></i> デバイス詳細</h5>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>IPアドレス</th>
                                    <th>サービス</th>
                                    <th>パス</th>
                                    <th>ポート</th>
                                    <th>状態</th>
                                </tr>
                            </thead>
                            <tbody>
                                {% for device in devices %}
                                <tr>
                                    <td><strong>{{ device.ip_address }}</strong></td>
                                    <td>{{ device.device_name }}</td>
                                    <td><code>{{ device.registration_path }}</code></td>
                                    <td><span class="badge bg-info">{{ device.port }}</span></td>
                                    <td>
                                        {% if device.status == 'active' %}
                                        <span class="badge bg-success">稼働中</span>
                                        {% else %}
                                        <span class="badge bg-danger">停止</span>
                                        {% endif %}
                                    </td>
                                </tr>
                                {% endfor %}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}}
send "\r"
send "TEMPLATE_EOF\r"
expect "root@"

# 既存のtopology_v2.htmlを置き換え
send "mv topology_fixed.html topology_v2.html\r"
expect "root@"

# lpg_admin.pyのプロセスを再起動
send "pkill -f lpg_admin.py\r"
expect "root@"

send "cd /opt/lpg/src\r"
expect "root@"

send "nohup python3 lpg_admin.py > /var/log/lpg_admin.log 2>&1 &\r"
expect "root@"

send "sleep 3\r"
expect "root@"

# プロセス確認
send "ps aux | grep lpg_admin | grep -v grep\r"
expect "root@"

send "exit\r"
expect eof
EOF

echo ""
echo "=== 修正完了 ==="
echo ""
echo "管理UIにアクセスして確認してください:"
echo "http://192.168.234.2:8443/topology"
echo ""
echo "認証情報: admin / lpgadmin123"