# ネットワーク障害防止システム

## 概要

2025年8月10日に発生した全ネットワーク障害インシデントを受けて、LPG（Lacis Proxy Gateway）に対して実装された包括的な障害防止・自動復旧システムについて説明します。

## インシデント概要

### 発生日時
- **2025年8月10日 AM 3:29 JST**

### 影響
- 全ネットワークのインターネット接続喪失
- 物理的介入まで復旧不可（約3時間のダウンタイム）

### 根本原因
1. LPGが0.0.0.0にバインドし、ネットワーク全体のトラフィックを阻害
2. 既存のセーフティ機構を貫通
3. 自動復旧メカニズムの欠如

## 実装された対策

### 1. Enhanced Network Watchdog v2.0

#### 主要機能
- **超高速監視**: 0.5秒間隔での0.0.0.0バインディング検出
- **自動ネットワーク復旧**: 6段階の復旧プロセス
- **最終手段としてのシステムリブート**: 3回の復旧失敗後に自動実行

#### ファイル
- `/opt/lpg/src/enhanced_network_watchdog.py`

#### 監視間隔の改善
| 項目 | 改修前 | 改修後 |
|------|--------|--------|
| 0.0.0.0検出 | 5秒 | **0.5秒** |
| ゲートウェイ監視 | 5秒 | **2秒** |
| プロセスkill | pkill | **SIGKILL + psutil** |

### 2. 多層防御アーキテクチャ（7層）

#### Layer 1: 事前ソケット検証
起動前に127.0.0.1:8443がバインド可能か確認

#### Layer 2: 設定ファイル強制
`safe_config.py`で0.0.0.0を完全拒否

#### Layer 3: ソースコードパッチ
`lpg_admin.py`を動的に修正して安全な値を強制

#### Layer 4: 環境変数の強制設定
```bash
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
```

#### Layer 5: 500ms間隔の継続監視
プリエンプティブな監視スレッドによる超高速検出

#### Layer 6: systemdレベルの制限
```ini
IPAddressAllow=127.0.0.1/32 ::1/128 192.168.234.0/24
IPAddressDeny=0.0.0.0/0
```

#### Layer 7: iptablesファイアウォール
カーネルレベルで0.0.0.0:8443をDROP

### 3. 自動ネットワーク復旧プロセス

#### 6段階復旧手順

##### Step 1: LPGプロセスの完全停止
```python
def step1_kill_all_lpg(self):
    self.instant_kill_lpg()
    subprocess.run(['systemctl', 'stop', 'lpg-admin.service'])
    subprocess.run(['systemctl', 'disable', 'lpg-admin.service'])
```

##### Step 2: ARPテーブルのクリア
```python
def step2_clear_arp_table(self):
    subprocess.run(['ip', '-s', 'neigh', 'flush', 'all'])
    subprocess.run(['arp', '-d', self.gateway_ip])
```

##### Step 3: ネットワークインターフェースのリセット
```python
def step3_reset_interface(self):
    subprocess.run(['ip', 'link', 'set', self.interface, 'down'])
    time.sleep(2)
    subprocess.run(['ip', 'addr', 'flush', 'dev', self.interface])
    subprocess.run(['ip', 'link', 'set', self.interface, 'up'])
```

##### Step 4: DHCPリースの更新
```python
def step4_renew_dhcp(self):
    subprocess.run(['dhclient', '-r', self.interface])
    subprocess.run(['dhclient', '-v', self.interface])
```

##### Step 5: 接続性の検証
```python
def step5_verify_connectivity(self):
    if not self.check_gateway_connectivity():
        return False
    socket.gethostbyname('google.com')  # DNS確認
```

##### Step 6: 安全なLPG再起動
```python
def step6_restart_safe_lpg(self):
    safe_env['LPG_ADMIN_HOST'] = '127.0.0.1'
    safe_env['LPG_ADMIN_PORT'] = '8443'
```

### 4. Hardened Admin Wrapper

#### ファイル
- `/opt/lpg/src/lpg_hardened_admin.py`

#### 主要機能
- 起動前のポート検証
- 動的なソースコードパッチング
- 継続的な0.0.0.0バインディング監視
- 危険な環境変数の除去

## systemdサービス設定

### lpg-watchdog-enhanced.service

```ini
[Service]
WatchdogSec=30
StartLimitIntervalSec=300
StartLimitBurst=3
StartLimitAction=reboot
```

- 30秒以内に応答がない場合、自動再起動
- 5分間に3回失敗した場合、システムリブート

### lpg-admin-hardened.service

```ini
[Service]
Environment="LPG_ADMIN_HOST=127.0.0.1"
Environment="LPG_ADMIN_PORT=8443"
IPAddressDeny=0.0.0.0/0
```

## デプロイメント

### インストールスクリプト
```bash
/opt/lpg/scripts/deploy_enhanced_safety.sh
```

このスクリプトは以下を実行：
1. 既存ファイルのバックアップ
2. 新コンポーネントのインストール
3. systemdサービスの設定
4. ハードウェアウォッチドッグの有効化
5. cronジョブの設定
6. iptablesルールの適用

## 監視とログ

### ログファイル
- `/var/log/lpg_watchdog.log` - Watchdogの動作ログ
- `/var/log/lpg_safety.log` - 安全機能のログ
- `/var/log/lpg_recovery.log` - ネットワーク復旧ログ
- `/var/log/lpg_emergency_reboot.flag` - 緊急リブート記録

### 監視コマンド
```bash
# Watchdog状態確認
systemctl status lpg-watchdog-enhanced

# ポートバインディング確認
ss -tlnp | grep 8443

# ログ監視
tail -f /var/log/lpg_watchdog.log
```

## テスト済み機能

### 2025年8月9日実施
1. ✅ Enhanced Watchdogの0.5秒間隔監視
2. ✅ 127.0.0.1バインディングの維持
3. ✅ Web UI（全ページ）の正常動作
4. ✅ ネットワーク接続性の確認
5. ✅ バックアップとリストア

## 推奨事項

### DMZ設定の変更
現在のDMZ設定（全ポート転送）から、特定ポート転送への変更を推奨：

```
ER605設定:
- 80 → 192.168.234.2:80
- 443 → 192.168.234.2:443
- DMZ: 無効化
```

この変更により、LPGの設計思想（80/443のみで全機能提供）に合致し、0.0.0.0バインディング時の影響を最小化できます。

## まとめ

本システムにより、以下が実現されました：

1. **0.0.0.0バインディングの即座検出**（0.5秒以内）
2. **自動ネットワーク復旧**（6段階プロセス）
3. **最悪ケースでの自動リブート**（5分以内）
4. **7層の多層防御**

これらの対策により、2025年8月10日のようなネットワーク全体障害の再発を防止し、万が一発生した場合でも自動的に復旧することが可能となりました。

---

*最終更新: 2025年8月9日*
*作成者: LACIS Team*