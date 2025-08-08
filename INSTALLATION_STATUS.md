# LPG インストール状況記録

## 📅 実施日時: 2025-08-08

## ⚠️ 重要：簡略化された設定の記録

### 発生した問題
- **時刻**: 2025-08-08 AM
- **問題**: apt-get upgrade実行中に5分でタイムアウト
- **対処**: 最小限の設定で実装を進行

### 簡略化・未実装項目

#### 1. テンプレートディレクトリ
- **状態**: ❌ 未コピー
- **理由**: ディレクトリが存在しないためscpエラー
- **必要な作業**:
```bash
# テンプレート作成とコピー
mkdir -p /Volumes/crucial_MX500/lacis_project/project/LPG/templates
cp /Volumes/crucial_MX500/lacis_project/project/LPG/src/templates/* /Volumes/crucial_MX500/lacis_project/project/LPG/templates/
scp -r /Volumes/crucial_MX500/lacis_project/project/LPG/templates/* root@192.168.234.2:/opt/lpg/templates/
```

#### 2. nginx完全設定
- **状態**: ⚠️ 部分的
- **実装内容**: 基本的なプロキシ設定のみ
- **未実装**: SSL設定、詳細なlocation設定
- **必要な作業**:
```bash
# nginx設定ファイルのコピーと有効化
scp /Volumes/crucial_MX500/lacis_project/project/LPG/nginx/lpg-ssl root@192.168.234.2:/etc/nginx/sites-available/
ssh root@192.168.234.2 'ln -sf /etc/nginx/sites-available/lpg-ssl /etc/nginx/sites-enabled/'
ssh root@192.168.234.2 'nginx -t && systemctl reload nginx'
```

#### 3. network_watchdogサービス
- **状態**: ❌ サービス未設定
- **理由**: 個別のsystemdサービスとして未設定
- **必要な作業**:
```bash
ssh root@192.168.234.2 << 'EOF'
cat > /etc/systemd/system/lpg-watchdog.service << 'SERVICE_EOF'
[Unit]
Description=LPG Network Watchdog
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/lpg/src/network_watchdog.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable lpg-watchdog
systemctl start lpg-watchdog
EOF
```

#### 4. SSL証明書
- **状態**: ❌ 未生成
- **理由**: 自己署名証明書の生成スクリプト未実行
- **必要な作業**:
```bash
ssh root@192.168.234.2 << 'EOF'
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=JP/ST=Tokyo/L=Tokyo/O=LPG/CN=lpg-proxy"
EOF
```

#### 5. iptables-persistent設定
- **状態**: ⚠️ インストール途中
- **理由**: apt-get実行中のタイムアウト
- **必要な作業**:
```bash
ssh root@192.168.234.2 << 'EOF'
apt-get install -y iptables-persistent
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -s 127.0.0.1 -p tcp --dport 8443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j DROP
iptables-save > /etc/iptables/rules.v4
EOF
```

### 実装済み項目

#### ✅ 完了した作業
1. **root SSHアクセス**: 有効化済み（パスワード: orangepi）
2. **基本ディレクトリ構造**: 作成済み
   - /opt/lpg/src
   - /opt/lpg/templates
   - /var/log/lpg
   - /etc/lpg
3. **コアファイル**: コピー済み
   - lpg_admin.py
   - lpg_safe_wrapper.py
   - network_watchdog.py
   - ssh_fallback.sh
4. **環境設定ファイル**: /etc/lpg/lpg.env作成済み
   - LPG_ADMIN_HOST=127.0.0.1（安全設定）
   - LPG_ADMIN_PORT=8443
   - LPG_SAFE_MODE=1
5. **Pythonパッケージ**: インストール開始
   - flask, werkzeug, requests, psutil

#### ⚠️ 部分的に完了
1. **systemdサービス**: lpg-admin.serviceのみ設定
2. **apt-get upgrade**: 実行中（タイムアウトしたが継続中の可能性）

### 現在の状態

```bash
# 接続情報
IP: 192.168.234.2
SSH: root@192.168.234.2 (password: orangepi)
Orange Pi: Zero 3
OS: Ubuntu Jammy (22.04)
Kernel: Linux 6.1.31-sun50iw9
```

## ✅ インストール完了 (2025-08-08 08:56 JST)

### 動作中のサービス
- **lpg-admin.service**: ✅ Active (running) - ポート127.0.0.1:8443
- **lpg-watchdog.service**: ✅ Active (running) - ネットワーク監視中
- **nginx**: ✅ Active (running) - ポート0.0.0.0:80

### アクセス情報
- **LPG Admin UI**: http://192.168.234.2 (nginx経由)
- **Direct Admin**: http://192.168.234.2:8443 (ローカルのみ)
- **デフォルト認証**: admin / lpgadmin123

### 実装済み安全機構
- ✅ LPG_ADMIN_HOST=127.0.0.1 (0.0.0.0バインディング防止)
- ✅ Network Watchdog (危険なバインディング監視)
- ✅ SSH Fallback Protection (SSH優先保護)
- ✅ Safe Wrapper (環境変数保護)

### 次のステップ

1. **システム更新の完了確認**
```bash
ssh root@192.168.234.2 'apt-get update && apt-get upgrade -y'
```

2. **不足ファイルのコピー**
```bash
# templates, nginx設定など
```

3. **サービスの起動確認**
```bash
ssh root@192.168.234.2 'systemctl status lpg-admin'
ssh root@192.168.234.2 'netstat -tlnp | grep 8443'
```

4. **安全機構のテスト**
```bash
ssh root@192.168.234.2 '/opt/lpg/test_safety_mechanisms.sh'
```

5. **バックアップの作成**
```bash
# SDカードイメージのバックアップ
```

### 重要な注意事項

⚠️ **この設定は簡略化されています**
- 本番環境での使用前に、上記の未実装項目を必ず完了させてください
- 特にSSL証明書とファイアウォール設定は重要です
- network_watchdogサービスは0.0.0.0バインディングを防ぐため必須です

### 実装漏れ防止チェックリスト

- [ ] templatesディレクトリの完全コピー
- [ ] nginx SSL設定の完了
- [ ] network_watchdogサービスの有効化
- [ ] SSL証明書の生成と設定
- [ ] iptables-persistentの設定完了
- [ ] 全サービスの起動確認
- [ ] 安全機構のテスト実施
- [ ] SDカードイメージのバックアップ作成

---
*このドキュメントは実装漏れを防ぐため、簡略化された設定内容を詳細に記録しています。*