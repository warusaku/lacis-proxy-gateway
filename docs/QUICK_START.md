# LPG クイックスタートガイド

## 概要

LacisProxyGateway (LPG) v1.0 のクイックスタートガイドです。このガイドでは、基本的なセットアップと使用方法を説明します。

## システム要件

- Orange Pi Zero 3 (4GB RAM)
- Orange Pi OS 1.0.2 Jammy (Ubuntu 22.04)
- ディスクイメージ: `Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img`
- Python 3.10以上
- nginx 1.18以上

## 基本セットアップ

### 1. LPGへのアクセス

```bash
# SSH接続
ssh root@192.168.234.2
# パスワード: orangepi
```

### 2. LPG管理UIへのアクセス

- **ローカルアクセス**: http://192.168.234.2:8443/
- **外部アクセス**: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/
- **ログイン情報**: 
  - ユーザー名: `admin`
  - パスワード: `lpgadmin123`

### 3. サービスの起動・停止

```bash
# LPG管理UIの起動
cd /opt/lpg/src
python3 lpg_admin.py

# システムサービスとして管理
systemctl start lpg-admin    # 起動
systemctl stop lpg-admin     # 停止
systemctl restart lpg-admin  # 再起動
systemctl status lpg-admin   # 状態確認
```

## 主な機能

### デバイス管理
1. 管理UIにログイン
2. サイドバーから「Devices」をクリック
3. 「Add Device」でデバイスを追加
4. デバイス情報を入力して保存

### ドメイン管理
1. サイドバーから「Domains」をクリック
2. プロキシされているドメインの一覧を確認
3. ドメインごとのアクセス統計を確認

### ログ確認
1. サイドバーから「Logs」をクリック
2. システムログとアクセスログを確認
3. リアルタイムでログをモニタリング

### トポロジー表示
1. サイドバーから「Topology」をクリック
2. ネットワーク構成を視覚的に確認
3. デバイスの接続状態を確認

## トラブルシューティング

### 502 Bad Gatewayエラー
```bash
# LPGサービスの確認
ps aux | grep lpg_admin
netstat -tlnp | grep 8443

# サービス再起動
pkill -f lpg_admin.py
cd /opt/lpg/src && python3 lpg_admin.py
```

### ログイン問題
- Cookieを削除してブラウザを再起動
- プライベートブラウジングモードで試す

### 外部アクセス問題
- SSL証明書の有効期限を確認
- nginx設定を確認: `/etc/nginx/sites-enabled/lpg-ssl`

## よくある質問

**Q: デフォルトパスワードを変更するには？**
A: 管理UIの「Settings」から変更できます。

**Q: バックアップはどこに保存されますか？**
A: `/opt/lpg/backups/`に保存されます。

**Q: ログファイルはどこにありますか？**
A: `/var/log/lpg_admin.log`と`/var/log/lpg_access.log`にあります。

## サポート

問題が解決しない場合は、以下を確認してください：
- 詳細なドキュメント: `/opt/lpg/docs/`
- システムログ: `journalctl -u lpg-admin -n 100`
- エラーログ: `/var/log/nginx/error.log`