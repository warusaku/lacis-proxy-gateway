#!/bin/bash

# LPG管理UIトポロジーページ修正スクリプト（修正版）
# 作成日: 2025-08-04

echo "=== LPG管理UIトポロジーページ修正 ==="
echo ""

# 直接SSH経由でテンプレートを修正
ssh root@192.168.234.2 << 'SSH_EOF'
cd /opt/lpg/src/templates

# バックアップ作成
BACKUP_NAME="topology_v2.html.bak.$(date +%Y%m%d_%H%M%S)"
cp topology_v2.html "$BACKUP_NAME"
echo "バックアップ作成: $BACKUP_NAME"

# 簡略化されたトポロジーテンプレートを作成
cat > topology_v2_fixed.html << 'TEMPLATE_EOF'
{% extends "base_dark.html" %}

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
                <!-- 背景 -->
                <rect width="100%" height="100%" fill="#0d1117"/>
                
                <!-- インターネット -->
                <g transform="translate(600, 50)">
                    <circle cx="0" cy="0" r="40" fill="#1f6feb" stroke="#58a6ff" stroke-width="2"/>
                    <text x="0" y="5" text-anchor="middle" fill="#ffffff" font-size="14" font-weight="bold">Internet</text>
                </g>
                
                <!-- LPG -->
                <g transform="translate(600, 250)">
                    <rect x="-80" y="-40" width="160" height="80" rx="10" fill="#238636" stroke="#2ea043" stroke-width="2"/>
                    <text x="0" y="0" text-anchor="middle" fill="#ffffff" font-size="16" font-weight="bold">
                        <tspan x="0" dy="-10">LPG</tspan>
                        <tspan x="0" dy="20" font-size="12">192.168.234.2</tspan>
                        <tspan x="0" dy="15" font-size="10" fill="#58a6ff">● 稼働中</tspan>
                    </text>
                </g>
                
                <!-- 接続線 -->
                <line x1="600" y1="90" x2="600" y2="210" stroke="#58a6ff" stroke-width="3"/>
                
                <!-- ドメイン -->
                {% for domain in domains %}
                <g transform="translate(300, {{ 150 + loop.index0 * 80 }})">
                    <rect x="-100" y="-25" width="200" height="50" rx="5" fill="#161b22" stroke="#30363d" stroke-width="1"/>
                    <text x="0" y="0" text-anchor="middle" fill="#c9d1d9" font-size="11">
                        <tspan x="0" dy="-5">{{ domain.domain_name[:25] }}</tspan>
                        <tspan x="0" dy="15" fill="#8b949e" font-size="9">
                            {% if domain.allowed_subnets %}{{ domain.allowed_subnets[0] }}{% else %}any{% endif %}
                        </tspan>
                    </text>
                    <line x1="100" y1="0" x2="220" y2="{{ 250 - 150 - loop.index0 * 80 }}" 
                          stroke="#30363d" stroke-width="1" stroke-dasharray="3,3"/>
                </g>
                {% endfor %}
                
                <!-- デバイス -->
                {% for device in devices %}
                <g transform="translate(900, {{ 150 + loop.index0 * 100 }})">
                    <rect x="-100" y="-40" width="200" height="80" rx="5" fill="#21262d" stroke="#f85149" stroke-width="1"/>
                    <text x="0" y="-20" text-anchor="middle" fill="#c9d1d9" font-size="12" font-weight="bold">
                        {{ device.ip_address }}
                    </text>
                    <text x="0" y="0" text-anchor="middle" fill="#8b949e" font-size="10">
                        <tspan x="0" dy="12">{{ device.device_name[:20] }}</tspan>
                    </text>
                    <circle cx="85" cy="-25" r="5" fill="#2ea043"/>
                    <line x1="-100" y1="0" x2="-220" y2="{{ 250 - 150 - loop.index0 * 100 }}" 
                          stroke="#30363d" stroke-width="2"/>
                </g>
                {% endfor %}
            </svg>
        </div>
    </div>

    <!-- LPGステータス -->
    <div class="card mb-3">
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
    
    <!-- デバイス詳細 -->
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
                                <span class="badge bg-success">稼働中</span>
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
{% endblock %}
TEMPLATE_EOF

# 既存のファイルを置き換え
mv topology_v2_fixed.html topology_v2.html
echo "テンプレートファイルを更新しました"

# lpg_admin.pyを再起動
pkill -f lpg_admin.py
cd /opt/lpg/src
nohup python3 lpg_admin.py > /var/log/lpg_admin.log 2>&1 &
sleep 3

# プロセス確認
if ps aux | grep -v grep | grep -q lpg_admin.py; then
    echo "lpg_admin.pyが正常に起動しました"
else
    echo "lpg_admin.pyの起動に失敗しました"
fi
SSH_EOF

echo ""
echo "=== 修正完了 ==="
echo "管理UIで確認: http://192.168.234.2:8443/topology"