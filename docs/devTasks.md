---
title: LacisProxyGateway 開発タスク記録
projects:
- LPG
tags:
- '#proj-lpg'
created: '2025-07-28'
updated: '2025-07-28'
author: unknown
status: draft
---
# LacisProxyGateway 開発タスク記録

## 2025-07-26

### Task: FTPサーバーの実装とデプロイメント機能の追加

**実行内容:**
1. vsftpdの設定ファイルを作成
   - `/config/vsftpd/vsftpd.conf`: FTPSサーバー設定
   - `/config/vsftpd/vsftpd.userlist`: 許可ユーザーリスト

2. FTPサーバー設定スクリプトの作成
   - `/scripts/setup-ftp.sh`: ユーザー作成、SSL証明書生成、vsftpd設定
   - `/scripts/ftp-deploy-watcher.sh`: アップロードファイル監視と自動デプロイ

3. Dockerfileの更新
   - vsftpd、openssl、inotify-tools、su-execパッケージを追加
   - lacisadminユーザーの作成（パスワード: lacis12345@）
   - FTPディレクトリ構造の設定

4. docker-compose.ymlの更新
   - FTPポート（21）とパッシブモードポート（30000-30100）を追加
   - FTPデータボリュームの追加

5. docker-entrypoint.shの作成
   - 各サービスの起動順序を管理
   - FTPサーバーとデプロイ監視の自動起動

6. FTPデプロイ手順書の作成
   - `/docs/FTPデプロイ手順書.md`: 使用方法とトラブルシューティング

7. Makefileの更新
   - `make ftp-setup`: FTPサーバーの初期設定
   - `make ftp-status`: サービス状態確認
   - `make ftp-logs`: ログ表示

**結果:**
- FTPSによる安全なファイル転送機能を実装
- アップロードされたファイルの自動デプロイ機能を実装
- config.json更新時のサービス自動再起動機能を実装

**課題:**
- 本番環境でのパスワード変更が必要
- IPアドレス制限の実装を検討

--- 