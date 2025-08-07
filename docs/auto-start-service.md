# LPG Safe Auto-Start Service Documentation

## 概要

LPG Safe Auto-Start Service は、停電やシステム再起動時に LPG (LacisProxyGateway) を安全に自動起動するためのシステムです。VLAN555 環境でのネットワーク衝突を完全に防止しながら、サービスの可用性を確保します。

## 背景と問題

### 発生していた問題
- LPG サービスが `0.0.0.0:8443` にバインドすると、VLAN555 全体のネットワークがダウンする
- 再起動のたびに手動でサービスを起動する必要があった
- 設定ミスによるネットワーク障害のリスクが常に存在していた

### 解決策
多層防御システムと安全チェック機能を実装した自動起動サービスを構築

## アーキテクチャ

```
[System Boot]
     ↓
[network-online.target]
     ↓
[lpg-safe.service]
     ↓
[lpg_safe_startup.sh]
     ├── System Check
     ├── Network Check
     ├── Config Validation
     ├── Safety Verification
     └── Service Start
           ├── lpg_admin.py (127.0.0.1:8443)
           └── monitor_network_safety.sh
```

## ファイル構成

### 1. サービスファイル
- **場所**: `/etc/systemd/system/lpg-safe.service`
- **役割**: systemd サービス定義
- **特徴**:
  - ネットワーク完全起動後に実行
  - 環境変数で安全設定を強制
  - 起動失敗時の自動リトライ（最大3回）

### 2. 起動スクリプト
- **場所**: `/opt/lpg/lpg_safe_startup.sh`
- **役割**: 安全チェックと起動制御
- **機能**:
  - 7段階の安全チェックプロセス
  - 自動修正機能
  - 詳細なログ記録

### 3. 環境設定ファイル
- **場所**: `/opt/lpg/lpg_config.env`
- **役割**: バインドアドレスの一元管理
- **重要設定**:
  ```bash
  export LPG_BIND_HOST="127.0.0.1"
  export LPG_SAFETY_MODE="ENABLED"
  export LPG_NETWORK_PROTECTION="MAXIMUM"
  ```

### 4. 監視スクリプト
- **場所**: `/opt/lpg/monitor_network_safety.sh`
- **役割**: 継続的な安全性監視
- **機能**: 0.0.0.0 バインドを検出したら即座にプロセスを停止

## 起動プロセス詳細

### Phase 1: システムチェック
```bash
# 実行内容
- ネットワークインターフェース (eth0) の起動待機
- IP アドレスの取得確認
- VLAN555 (192.168.234.x) への接続確認
```

### Phase 2: ネットワークチェック
```bash
# 実行内容
- 危険なポート使用の確認 (0.0.0.0:8443, 0.0.0.0:8080)
- 既存の危険なプロセスの自動停止
- ゲートウェイ (192.168.234.1) への到達性確認
```

### Phase 3: 設定ファイルチェック
```bash
# 実行内容
- 環境設定ファイルの読み込み
- 0.0.0.0 設定の検出と自動修正
- lpg_admin.py 内の危険な設定の自動置換
```

### Phase 4: 起動前最終確認
```bash
# 実行内容
- エラーカウントの評価
- メモリ使用状況の確認
- 既存プロセスのクリーンアップ
```

### Phase 5: LPG サービス起動
```bash
# 実行内容
- lpg_admin.py を 127.0.0.1:8443 で起動
- プロセス ID の記録
- バインドアドレスの検証
```

### Phase 6: 監視システム起動
```bash
# 実行内容
- monitor_network_safety.sh の起動
- 継続的な安全性監視の開始
```

### Phase 7: 起動完了報告
```bash
# 実行内容
- ステータスレポートの生成
- ログファイルへの記録
```

## 安全機能

### 1. 自動フォールバック
0.0.0.0 が設定されていた場合、自動的に 127.0.0.1 に変更

```python
# lpg_admin.py の自動修正例
# 変更前: host = '0.0.0.0'
# 変更後: host = '127.0.0.1'  # Auto-fixed from 0.0.0.0
```

### 2. 多層防御
- **Layer 1**: 環境変数による制御
- **Layer 2**: スクリプトレベルの検証
- **Layer 3**: 起動時の自動修正
- **Layer 4**: 実行時の継続監視
- **Layer 5**: 危険検出時の自動停止

### 3. ログ記録
すべてのチェックと操作が詳細にログに記録される

## ログファイル

| ファイル | 内容 | ローテーション |
|---------|------|--------------|
| `/var/log/lpg_startup.log` | 起動時のチェック結果 | 手動 |
| `/var/log/lpg_admin.log` | LPG サービスログ | 日次 |
| `/var/log/lpg_monitor.log` | 監視システムログ | 週次 |
| `/var/log/lpg_safety.log` | 安全性違反の記録 | 月次 |

## 運用コマンド

### サービス管理
```bash
# サービス状態確認
systemctl status lpg-safe.service

# サービス停止
systemctl stop lpg-safe.service

# サービス開始
systemctl start lpg-safe.service

# サービス再起動
systemctl restart lpg-safe.service

# 自動起動の無効化
systemctl disable lpg-safe.service

# 自動起動の有効化
systemctl enable lpg-safe.service
```

### 手動起動
```bash
# 安全チェック付き起動
/opt/lpg/lpg_safe_startup.sh

# 究極安全起動（追加チェック付き）
/opt/lpg/start_lpg_ultimate_safe.sh
```

### ログ確認
```bash
# 起動ログの確認
tail -f /var/log/lpg_startup.log

# サービスログの確認
journalctl -u lpg-safe.service -f

# 最新の起動結果
grep "Status:" /var/log/lpg_startup.log | tail -1
```

## トラブルシューティング

### Q: サービスが起動しない
```bash
# 1. ログを確認
journalctl -u lpg-safe.service -n 50

# 2. スクリプトを手動実行してエラー確認
/opt/lpg/lpg_safe_startup.sh

# 3. ネットワーク状態確認
ip addr show
netstat -tlnp | grep 8443
```

### Q: 0.0.0.0 バインドエラーが発生
```bash
# 1. プロセスを停止
pkill -f lpg_admin.py

# 2. 設定ファイルを確認
grep "0.0.0.0" /opt/lpg/src/lpg_admin.py
cat /opt/lpg/lpg_config.env

# 3. 安全起動を実行
/opt/lpg/start_lpg_ultimate_safe.sh
```

### Q: ネットワークに接続できない
```bash
# 1. VLAN 設定確認
ip addr show | grep 192.168.234

# 2. ゲートウェイ確認
ping -c 2 192.168.234.1

# 3. DNS 確認
nslookup google.com
```

## セキュリティ考慮事項

### 1. バインドアドレス
- **必須**: 127.0.0.1 のみを使用
- **禁止**: 0.0.0.0 は絶対に使用しない
- **理由**: VLAN555 でのネットワーク衝突防止

### 2. アクセス制御
- nginx 経由でのみ外部アクセスを許可
- 直接ポートアクセスは localhost のみ

### 3. 権限管理
- サービスは root 権限で実行（ネットワーク設定のため）
- ログファイルは root のみ書き込み可能

## メンテナンス

### 定期確認項目
1. ログファイルのサイズ確認（月次）
2. 起動時間の確認（週次）
3. エラーログの確認（日次）

### アップデート手順
1. サービス停止
2. スクリプトファイルの更新
3. systemd リロード
4. サービス再起動
5. 動作確認

## 変更履歴

| 日付 | バージョン | 変更内容 |
|-----|-----------|---------|
| 2025-08-06 | 1.0.0 | 初版作成、安全自動起動機能実装 |

## 関連ドキュメント

- [LPG システム概要](./README.md)
- [ネットワーク設定ガイド](./network-setup.md)
- [セキュリティガイドライン](./security.md)

## サポート

問題が発生した場合は、以下の情報を含めて報告してください：

1. `/var/log/lpg_startup.log` の最新エントリ
2. `systemctl status lpg-safe.service` の出力
3. `netstat -tlnp | grep 8443` の結果
4. 発生時刻と症状の詳細

---

*このドキュメントは LPG Safe Auto-Start Service v1.0.0 に対応しています*