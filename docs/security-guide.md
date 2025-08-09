# LPG セキュリティガイド

## ⚠️ 最重要事項

**絶対に0.0.0.0にバインドしない！**

過去の重大インシデント（2025年8月6日）により、ネットワーク全体がダウンしました。この教訓から、厳格なセキュリティ対策が実装されています。

## 目次
1. [重大セキュリティリスク](#重大セキュリティリスク)
2. [ネットワーク保護機構](#ネットワーク保護機構)
3. [バインドアドレス設定](#バインドアドレス設定)
4. [VLAN環境での注意事項](#vlan環境での注意事項)
5. [安全機構の詳細](#安全機構の詳細)
6. [アクセス制御](#アクセス制御)
7. [SSL/TLS設定](#ssltls設定)
8. [ログとモニタリング](#ログとモニタリング)
9. [インシデント対応](#インシデント対応)
10. [セキュリティチェックリスト](#セキュリティチェックリスト)

## 重大セキュリティリスク

### 過去のインシデント

#### 2025年8月6日 ネットワーク全体ダウン事件

**発生原因**:
```python
# 危険なコード（絶対に使用禁止）
app.run(host='0.0.0.0', port=8443)  # これがVLAN全体をクラッシュさせた
```

**影響範囲**:
- TP-Link Omada ER605ルーターのVLAN555が完全停止
- 全ネットワークセグメントが通信不能
- ARPテーブルの破損
- 復旧に数時間を要した

**根本原因**:
1. LPGが0.0.0.0:8443でリッスン
2. ER605のVLAN555インターフェースと競合
3. ARPブロードキャストストーム発生
4. ルーティングループによる全体障害

### リスクレベル

| リスクレベル | 説明 | 対策 |
|------------|------|------|
| **CRITICAL** | ネットワーク全体障害 | 0.0.0.0バインド禁止 |
| **HIGH** | サービス停止 | 適切なエラーハンドリング |
| **MEDIUM** | 不正アクセス | 認証・認可の強化 |
| **LOW** | 情報漏洩 | ログの適切な管理 |

## ネットワーク保護機構

### 多層防御アーキテクチャ

```
レイヤー1: network_watchdog.py
  ↓ 監視・検出
レイヤー2: lpg_safe_wrapper.py
  ↓ 環境変数保護
レイヤー3: systemdサービス
  ↓ 設定強制
レイヤー4: Nginxリバースプロキシ
  ↓ 外部アクセス制御
アプリケーション層
```

### network_watchdog.py

**機能**:
- 0.0.0.0へのバインド検出
- 危険なプロセスの即座終了（SIGKILL）
- ネットワーク状態の継続監視
- 異常検出時のアラート

**動作例**:
```python
def check_port_binding(self):
    """危険なバインドを検出"""
    connections = psutil.net_connections()
    for conn in connections:
        if conn.status == 'LISTEN' and conn.laddr.ip == '0.0.0.0':
            # LPGプロセスなら即座にKILL
            if 'lpg' in proc.name():
                os.kill(proc.pid, signal.SIGKILL)
                logging.critical(f"KILLED DANGEROUS PROCESS: {proc.name()}")
```

### lpg_safe_wrapper.py

**機能**:
- 環境変数の検証と強制
- 安全な起動パラメータの保証
- ランタイム監視
- 異常終了時の自動復旧

**実装**:
```python
# 環境変数の強制
os.environ['LPG_ADMIN_HOST'] = '127.0.0.1'  # 絶対に変更不可
os.environ['LPG_PROXY_HOST'] = '127.0.0.1'  # 絶対に変更不可

# 危険な設定を検出
if host == '0.0.0.0':
    logging.critical("DANGEROUS: Attempted to bind to 0.0.0.0")
    sys.exit(1)
```

## バインドアドレス設定

### 正しい設定

#### ✅ 安全な設定
```bash
# systemdサービス
Environment="LPG_ADMIN_HOST=127.0.0.1"
Environment="LPG_PROXY_HOST=127.0.0.1"

# Nginx経由でのみ外部アクセス
proxy_pass http://127.0.0.1:8443/;
```

#### ❌ 危険な設定（絶対禁止）
```bash
# これらは絶対に使用しない
Environment="LPG_ADMIN_HOST=0.0.0.0"  # NG!
Environment="LPG_PROXY_HOST=0.0.0.0"  # NG!
app.run(host='0.0.0.0')  # NG!
```

### 設定の確認方法

```bash
# 現在のバインド状態を確認
netstat -tlnp | grep -E '8080|8443'

# 正しい出力例
tcp  0  0  127.0.0.1:8443  0.0.0.0:*  LISTEN  1234/python3
tcp  0  0  127.0.0.1:8080  0.0.0.0:*  LISTEN  5678/python3

# 危険な出力例（この場合は即座に停止必要）
tcp  0  0  0.0.0.0:8443  0.0.0.0:*  LISTEN  xxxx/python3  # 危険！
```

## VLAN環境での注意事項

### ER605との相互作用

**問題のメカニズム**:
1. LPGが0.0.0.0でリッスン
2. VLAN555インターフェースと競合
3. MACアドレステーブルの混乱
4. ブロードキャストストーム発生
5. ネットワーク全体の通信断絶

### VLAN設定のベストプラクティス

```bash
# 1. 単一インターフェースのみ使用
ip addr show | grep "inet "

# 2. VLANタグの明示的設定
nmcli con add type vlan \
  con-name vlan555 \
  dev eth0 \
  id 555 \
  ipv4.addresses 192.168.234.2/24

# 3. ブロードキャストの制限
iptables -A INPUT -m pkttype --pkt-type broadcast -j DROP
```

### ARPテーブルの保護

```bash
# 静的ARPエントリの設定
arp -s 192.168.234.1 xx:xx:xx:xx:xx:xx

# ARPフラッド対策
echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
```

## 安全機構の詳細

### SSH Fallback Protection

**ssh_fallback.sh**:
```bash
#!/bin/bash
# ネットワーク障害時でもSSHアクセスを維持

# 緊急用SSHポートを開く
iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# ローカルネットワークからのアクセスを許可
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT

# LPGサービスを停止
systemctl stop lpg-admin lpg-proxy

# 緊急フラグを設定
touch /var/run/lpg_emergency_mode
```

### プロセス監視

```python
# network_watchdog.pyの監視ロジック
def monitor_lpg_processes():
    for proc in psutil.process_iter(['pid', 'name', 'connections']):
        if 'lpg' in proc.info['name']:
            for conn in proc.connections():
                if conn.laddr.ip == '0.0.0.0':
                    # 即座に終了
                    proc.kill()
                    alert_admin(f"Killed dangerous process: {proc.info['name']}")
```

### 自動復旧機能

```bash
# systemdの自動再起動設定
[Service]
Restart=on-failure
RestartSec=5
StartLimitBurst=3
StartLimitInterval=60
```

## アクセス制御

### ファイアウォール設定

```bash
# UFW設定
ufw default deny incoming
ufw default allow outgoing

# 必要最小限のポート開放
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Nginx)
ufw allow 443/tcp   # HTTPS (Nginx)

# LPGポートは外部から直接アクセス禁止
ufw deny 8080/tcp
ufw deny 8443/tcp

# ローカルネットワークのみ許可
ufw allow from 192.168.234.0/24 to any port 22
```

### Nginx アクセス制限

```nginx
# 管理UIへのアクセス制限
location /lpg-admin/ {
    # IPアドレス制限
    allow 192.168.234.0/24;
    allow 10.0.0.0/8;
    deny all;
    
    # レート制限
    limit_req zone=admin burst=5 nodelay;
    
    # セキュリティヘッダー
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    proxy_pass http://127.0.0.1:8443/;
}
```

### 認証強化

```python
# パスワードポリシー
MIN_PASSWORD_LENGTH = 12
REQUIRE_SPECIAL_CHARS = True
REQUIRE_NUMBERS = True
REQUIRE_UPPERCASE = True

# ログイン試行制限
MAX_LOGIN_ATTEMPTS = 5
LOCKOUT_DURATION = 300  # 5分

# セッション管理
SESSION_TIMEOUT = 1800  # 30分
SECURE_COOKIE = True
HTTPONLY_COOKIE = True
```

## SSL/TLS設定

### Let's Encrypt設定

```bash
# 証明書の取得
certbot certonly --nginx \
  -d your-domain.com \
  --email admin@example.com \
  --agree-tos

# 自動更新設定
cat > /etc/cron.d/certbot << EOF
0 0,12 * * * root certbot renew --quiet --no-self-upgrade
EOF
```

### Nginx SSL設定

```nginx
# 強力な暗号化設定
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;

# HSTS
add_header Strict-Transport-Security "max-age=63072000" always;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
```

## ログとモニタリング

### ログ設定

```python
# ログレベル設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/lpg_admin.log'),
        logging.StreamHandler()
    ]
)

# セキュリティイベントログ
def log_security_event(event_type, details):
    logger.warning(f"SECURITY: {event_type} - {details}")
    # アラート送信
    if event_type in ['INTRUSION', 'DDOS', 'BREACH']:
        send_admin_alert(event_type, details)
```

### 監視項目

| 項目 | 閾値 | アクション |
|------|------|-----------|
| CPU使用率 | >80% | アラート |
| メモリ使用率 | >90% | アラート+自動再起動 |
| ディスク使用率 | >85% | ログローテーション |
| 接続数 | >1000 | レート制限強化 |
| ログインfails | >5/分 | IP一時ブロック |
| 0.0.0.0バインド | 検出時 | 即座にプロセスKILL |

## インシデント対応

### 緊急時の手順

#### Step 1: サービス停止
```bash
sudo systemctl stop lpg-admin lpg-proxy
sudo pkill -f lpg
```

#### Step 2: ネットワーク分離
```bash
# ネットワークインターフェース停止
sudo ifdown eth0
# または
sudo ip link set eth0 down
```

#### Step 3: ログ収集
```bash
# ログの保全
sudo tar -czf /tmp/incident_logs_$(date +%Y%m%d_%H%M%S).tar.gz \
  /var/log/lpg*.log \
  /var/log/syslog \
  /var/log/nginx/
```

#### Step 4: 原因調査
```bash
# プロセス確認
ps aux | grep -E 'lpg|python'

# ネットワーク接続確認
netstat -tlnp
lsof -i

# ログ分析
grep -E 'ERROR|CRITICAL|0.0.0.0' /var/log/lpg*.log
```

#### Step 5: 復旧
```bash
# 設定確認
grep LPG_.*_HOST /etc/systemd/system/lpg*.service

# 安全確認後、サービス再起動
sudo systemctl start lpg-proxy
sudo systemctl start lpg-admin
```

### インシデント報告

報告に含める情報:
- 発生日時
- 影響範囲
- 検出方法
- 実施した対応
- 根本原因
- 再発防止策

## セキュリティチェックリスト

### 日次チェック
- [ ] ログインfailの確認
- [ ] アクセスログの異常確認
- [ ] プロセス状態確認
- [ ] バインドアドレス確認

### 週次チェック
- [ ] システムアップデート確認
- [ ] 証明書有効期限確認
- [ ] バックアップ確認
- [ ] セキュリティログ分析

### 月次チェック
- [ ] パスワード変更
- [ ] アクセス権限レビュー
- [ ] ファイアウォールルール見直し
- [ ] インシデント訓練

### 設定確認コマンド

```bash
#!/bin/bash
# セキュリティ設定確認スクリプト

echo "=== LPG Security Check ==="

# バインドアドレス確認
echo -e "\n[Bind Address Check]"
netstat -tlnp | grep -E '8080|8443'

# プロセス確認
echo -e "\n[Process Check]"
ps aux | grep -E 'lpg|watchdog' | grep -v grep

# 環境変数確認
echo -e "\n[Environment Check]"
systemctl show lpg-admin -p Environment
systemctl show lpg-proxy -p Environment

# ファイアウォール確認
echo -e "\n[Firewall Check]"
ufw status numbered

# 証明書確認
echo -e "\n[Certificate Check]"
certbot certificates

# ログエラー確認
echo -e "\n[Recent Errors]"
grep -E 'ERROR|CRITICAL' /var/log/lpg*.log | tail -10

echo -e "\n=== Check Complete ==="
```

## まとめ

LPGのセキュリティは、過去の重大インシデントから学んだ教訓に基づいて設計されています。特に0.0.0.0へのバインド禁止は、ネットワーク全体の安全性を保つための最重要事項です。

**常に覚えておくべきこと**:
1. 絶対に0.0.0.0にバインドしない
2. 環境変数でバインドアドレスを強制
3. network_watchdogによる継続監視
4. 定期的なセキュリティチェック
5. インシデント対応手順の習熟

これらの対策により、安全で信頼性の高いプロキシサービスを提供できます。