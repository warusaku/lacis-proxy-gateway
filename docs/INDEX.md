# LPG Documentation Index

## LacisProxyGateway v1.0 ドキュメント一覧

### 概要・仕様
- [README.md](README.md) - プロジェクト概要とメイン情報
- [SYSTEM_SPECIFICATION.md](SYSTEM_SPECIFICATION.md) - システム基本仕様書（ハードウェア・ソフトウェア仕様）
- [CHANGELOG.md](CHANGELOG.md) - バージョン履歴と変更内容

### セットアップ・運用
- [QUICK_START.md](QUICK_START.md) - クイックスタートガイド
- [INSTALLATION.md](INSTALLATION.md) - 詳細インストールガイド（OSイメージ情報含む）
- [DEPLOYMENT.md](DEPLOYMENT.md) - デプロイメント手順
- [HTTPS_CONFIGURATION.md](HTTPS_CONFIGURATION.md) - HTTPS/SSL設定ガイド

### API・開発
- [API_REFERENCE.md](API_REFERENCE.md) - API仕様リファレンス

### トラブルシューティング
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - トラブルシューティングガイド

## システム情報

### ハードウェア
- **デバイス**: Orange Pi Zero 3
- **CPU**: Allwinner H618 (Cortex-A53)
- **RAM**: 4GB
- **ストレージ**: microSD 16GB以上推奨

### OS情報
- **ディストリビューション**: Orange Pi 1.0.2 Jammy (Ubuntu 22.04 LTS)
- **カーネル**: Linux 6.1.31
- **ディスクイメージ**: `Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img`

### ネットワーク構成
- **IPアドレス**: 192.168.234.2
- **管理UIポート**: 8443
- **外部アクセスURL**: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/

### 主要コンポーネント
- **Webサーバー**: nginx 1.18.0
- **アプリケーション**: Flask 2.x + Python 3.10
- **UI**: 統一ダークテーマ（Bootstrap 5）
- **可視化**: D3.js v7

## アーカイブ

古いバージョンのドキュメントは[archive/old_versions/](archive/old_versions/)に保管されています。

## 更新履歴

- 2025-08-05: v1.0 リリース、ドキュメント整理完了
- 2025-08-05: Orange Pi Zero 3対応、OSイメージ情報追加
- 2025-08-03: 初期ドキュメント作成