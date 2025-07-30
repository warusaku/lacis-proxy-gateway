---
title: LacisProxyGateway FTPデプロイ手順書
projects:
- LPG
tags:
- '#proj-lpg'
created: '2025-07-28'
updated: '2025-07-28'
author: unknown
status: draft
---
# LacisProxyGateway FTPデプロイ手順書

**Version: 1.0.0**  
**作成日: 2025-07-26**

---

## 概要

LacisProxyGateway（LPG）へのファイル転送とデプロイメントをFTP経由で行うための手順書です。

## FTPサーバー情報

| 項目 | 内容 |
|------|------|
| プロトコル | FTPS（SSL/TLS必須） |
| ホスト | LPGのIPアドレス（例: 192.168.234.2） |
| ポート | 21 |
| ユーザー名 | lacisadmin |
| パスワード | lacis12345@ |
| パッシブモードポート | 30000-30100 |

## ディレクトリ構成

```
/var/ftp/lpg/
├── upload/   # ファイルアップロード先
├── deploy/   # デプロイ済みファイル保管
└── backup/   # バックアップ保管
```

## デプロイ手順

### 1. FTPクライアントの設定

推奨FTPクライアント:
- FileZilla（Windows/Mac/Linux）
- CyberDuck（Mac）
- WinSCP（Windows）

接続設定:
1. 「サイトマネージャー」を開く
2. 新しいサイトを作成
3. 以下の情報を入力:
   - ホスト: LPGのIPアドレス
   - ポート: 21
   - プロトコル: FTP - ファイル転送プロトコル
   - 暗号化: 明示的なFTP over TLSが必要
   - ログオンタイプ: 通常
   - ユーザー: lacisadmin
   - パスワード: lacis12345@

### 2. ファイルのアップロード

1. FTPクライアントでLPGに接続
2. `/var/ftp/lpg/upload/`ディレクトリに移動
3. デプロイしたいファイルをアップロード

### 3. 自動デプロイの仕組み

アップロードされたファイルは自動的に以下のように処理されます:

| ファイル名 | デプロイ先 | 備考 |
|-----------|----------|------|
| config.json | /etc/lpg/config.json | LPGサービス自動再起動 |
| lpg-api | /usr/local/bin/lpg-api | APIサービス自動再起動 |
| *.html, *.js, *.css | /var/www/html/ | 即座に反映 |
| *.sh | /usr/local/bin/ | 実行権限自動付与 |

### 4. デプロイログの確認

デプロイの結果は以下のログファイルで確認できます:
```
/var/log/lpg/ftp-deploy.log
```

SSH経由でログを確認:
```bash
ssh lacisadmin@192.168.234.2
tail -f /var/log/lpg/ftp-deploy.log
```

## トラブルシューティング

### 接続できない場合

1. ファイアウォール設定を確認
   - ポート21と30000-30100が開いているか
   
2. vsftpdサービスの状態を確認
   ```bash
   systemctl status vsftpd
   ```

### ファイルがデプロイされない場合

1. アップロード先が正しいか確認（`/var/ftp/lpg/upload/`）
2. ファイル名が対応しているか確認
3. デプロイログを確認

### SSL/TLS接続エラー

1. FTPクライアントの暗号化設定を確認
2. 「明示的なFTP over TLS」を選択
3. 証明書の警告が出た場合は「常に信頼する」を選択

## セキュリティ注意事項

1. **パスワードの管理**
   - デフォルトパスワードは必ず変更してください
   - 定期的なパスワード変更を推奨

2. **アクセス制限**
   - FTPアクセスは信頼できるIPアドレスからのみ許可
   - 不要な場合はFTPサービスを停止

3. **ログの監視**
   - 定期的にFTPアクセスログを確認
   - 不審なアクセスがないか監視

## バックアップとリストア

### バックアップの確認

デプロイ前の自動バックアップ:
```bash
ls -la /var/ftp/lpg/backup/
```

### リストア手順

1. バックアップファイルを確認
2. 手動でファイルを元の場所にコピー
   ```bash
   cp /var/ftp/lpg/backup/config.json.20250726_123456 /etc/lpg/config.json
   systemctl restart lpg-api
   ```

## 運用上の推奨事項

1. **定期メンテナンス**
   - 月1回: バックアップディレクトリのクリーンアップ
   - 週1回: ログファイルの確認

2. **監視項目**
   - FTPアクセスログ
   - デプロイメントログ
   - ディスク使用率

3. **セキュリティアップデート**
   - vsftpdの定期的なアップデート
   - SSL証明書の更新（年1回） 