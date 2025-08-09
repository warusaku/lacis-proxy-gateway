# LPG (Lacis Proxy Gateway) v2.0.0

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Python](https://img.shields.io/badge/python-3.10%2B-blue)
![Security](https://img.shields.io/badge/security-critical-red)

セキュアなPythonベースのリバースプロキシゲートウェイ。Web管理インターフェースと包括的な安全機構を搭載。

## 🛡️ セキュリティファースト

**⚠️ 重要**: 本バージョンには、実運用環境での重大インシデントから学んだ教訓に基づき、システム全体の障害を防ぐための多層防御機構が実装されています。

### 安全機能:
- **ネットワーク監視**: 危険なアドレス(0.0.0.0)へのバインドを検出し即座にプロセスを終了
- **SSHフォールバック保護**: ネットワーク障害時でもSSHアクセスを維持
- **セーフラッパー**: ランタイム監視と環境変数保護
- **Systemd統合**: 適切なサービス依存関係と安全性チェック

## 概要

LPGは、LacisDrawBoardsシステム用のWeb管理インターフェースを備えたHTTP/HTTPSリバースプロキシ機能を提供します。ドメインとパスの設定に基づいてバックエンドサービスへリクエストをルーティングします。

## 主な機能

- **リバースプロキシ**: ドメインとパスベースのルーティング
- **Web管理UI**: ダークテーマの統一インターフェース
- **トポロジービュー**: D3.jsによるプロキシ関係の視覚的表現
- **デバイス管理**: バックエンドサービスのCRUD操作
- **ユーザー管理**: 管理者ユーザーの作成と管理
- **ロギング**: タイムゾーン対応のアクセスログと操作ログ
- **HTTPSサポート**: Nginx経由でのLet's Encrypt統合
- **ネットワーク保護**: 多層安全機構

## ⚠️ 重要なインストール注意事項

**環境保護なしで管理インターフェースを実行しないでください！**

### 安全なインストール

```bash
# 1. リポジトリのクローン
git clone https://github.com/warusaku/lacis-proxy-gateway.git
cd lacis-proxy-gateway

# 2. 安全インストールスクリプトの実行
sudo ./install.sh

# 3. 安全機構のテスト（テスト環境のみ！）
sudo ./test_safety_mechanisms.sh
```

### 手動インストール（注意して使用）

```bash
# 依存関係のインストール
pip3 install flask werkzeug requests psutil

# 重要: 環境変数の設定
export LPG_ADMIN_HOST=127.0.0.1  # 絶対に0.0.0.0を使用しない！
export LPG_ADMIN_PORT=8443
export LPG_PROXY_HOST=127.0.0.1  # プロキシも同様
export LPG_PROXY_PORT=8080

# systemdサービス使用（推奨）
sudo systemctl start lpg-admin
sudo systemctl start lpg-proxy

# またはセーフラッパー使用
python3 src/lpg_safe_wrapper.py
```

## アクセス

- 管理UI: https://[your-domain]/lpg-admin/ (Nginx経由)
- 直接アクセス: http://127.0.0.1:8443 (ローカルのみ)
- デフォルト認証: admin / lpgadmin123

## ディレクトリ構造

```
LPG/
├── src/                     # ソースコード
│   ├── lpg_admin.py        # 管理インターフェース (Flask)
│   ├── lpg-proxy.py        # メインプロキシサーバー
│   ├── lpg_safe_wrapper.py # 安全ラッパー
│   ├── network_watchdog.py # ネットワーク監視
│   ├── ssh_fallback.sh     # SSH保護
│   ├── config.json         # プロキシ設定
│   ├── devices.json        # デバイス情報
│   └── templates/          # HTMLテンプレート (統一ダークテーマ)
├── systemd/                # 安全性を考慮したサービスファイル
├── nginx/                  # Nginx設定
├── scripts/                # デプロイメントとテスト
├── docs/                   # ドキュメント
├── diskimage/              # ディスクイメージ
├── install.sh              # 安全インストールスクリプト
└── test_safety_mechanisms.sh # 安全テストスイート
```

## 🚨 重要な安全規則

### ❌ 絶対にやってはいけないこと:
```python
# ネットワーク全体のVLANをクラッシュさせます！
app.run(host='0.0.0.0', port=8443)
```

```bash
# 環境保護なし！
nohup python3 lpg_admin.py &
```

### ✅ 常にこうすること:
```bash
# 環境変数を使用
export LPG_ADMIN_HOST=127.0.0.1
python3 src/lpg_safe_wrapper.py

# またはsystemdサービスを使用
sudo systemctl start lpg-admin
```

## ドキュメント

- [インストールガイド](docs/installation-guide.md)
- [設定ガイド](docs/configuration-guide.md)
- [操作ガイド](docs/operation-guide.md)
- [APIエンドポイント](docs/api-endpoints.md)
- [セキュリティガイド](docs/security-guide.md)
- [トラブルシューティング](docs/troubleshooting.md)

## 緊急時の復旧

ネットワーク問題が発生した場合:

1. SSHアクセス (ssh_fallback.shで保護)
2. サービス停止: `sudo systemctl stop lpg-admin lpg-proxy`
3. フラグクリア: `sudo rm -f /var/run/lpg_emergency_*`
4. ログ確認: `sudo tail -100 /var/log/lpg_admin.log`
5. 安全に再起動: `sudo systemctl start lpg-proxy lpg-admin`

## サポート

問題が発生した場合は、[Issues](https://github.com/warusaku/lacis-proxy-gateway/issues)で報告してください。

## ライセンス

MIT License - LacisDrawBoardsシステムの一部として提供
