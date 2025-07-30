# LacisProxyGateway (LPG)

Orange Pi Zero 3 ベース「リバースプロキシ＋ルーティング」アプライアンス

## 概要

LacisProxyGateway (LPG) は、Omada SDN環境下で動作する軽量なリバースプロキシ・ルーティングアプライアンスです。
外部からのHTTP/HTTPS/WebSocketトラフィックを一元的に受信し、ドメイン名とパスに基づいて内部の各種サービスへ振り分けます。

### 主な特徴

- 🚀 **軽量・高速** - Orange Pi Zero 3（4GB RAM）で快適動作
- 🔒 **セキュアなルーティング** - VLAN間の厳密なアクセス制御
- 🎯 **柔軟な振り分け** - ドメイン＋パスベースの詳細なルーティング
- 📊 **統合管理UI** - React + Primer Design Systemによる直感的な操作
- 🔄 **ホットリロード** - 設定変更の即時反映（ダウンタイムなし）
- 📝 **詳細なログ** - JSON形式でのアクセスログと外部送信対応
- 🛡️ **自動HTTPS** - Let's Encrypt統合による証明書自動管理

## システム構成

```
┌─────────── WAN (ISP) ────────────┐
▼                                  │
┌──────────────┐                    │
│  Omada GW    │ 192.168.3.1/24    │
│ (ER7206 等)  │                    │
└─────┬────────┘                    │
      │ DNAT 80/443 → 192.168.234.2 │
      ▼                             │
┌────────────────────────────────────┐
│ LacisProxyGateway (192.168.234.2) │
│  • Caddy (リバースプロキシ)         │
│  • API Server (Go)                │
│  • Web UI (React)                 │
└────────────────────────────────────┘
      │
      ▼ ルーティング
┌─────────────┬──────────────┬──────────────┐
│ Service A   │  Service B   │  Service C   │
│ 192.168.234.10 │ 192.168.234.20 │ 192.168.234.30 │
└─────────────┴──────────────┴──────────────┘
```

## クイックスタート

### 前提条件

- Orange Pi Zero 3 (4GB RAM推奨)
- Armbian 24.5 LTS または互換OS
- Go 1.21以上
- Node.js 18以上
- Docker（オプション）

### インストール

1. **リポジトリのクローン**
   ```bash
   git clone https://github.com/lacis/lpg.git
   cd lpg
   ```

2. **依存関係のインストール**
   ```bash
   # Go依存関係
   go mod download
   
   # Node.js依存関係
   npm install
   ```

3. **ビルド**
   ```bash
   # APIサーバー
   go build -o lpg-api ./src/api
   
   # フロントエンド
   npm run build
   ```

4. **設定ファイルの準備**
   ```bash
   sudo mkdir -p /etc/lpg
   sudo cp config/config.example.json /etc/lpg/config.json
   # 設定を編集
   sudo nano /etc/lpg/config.json
   ```

5. **サービスの起動**
   ```bash
   sudo ./scripts/install.sh
   sudo systemctl start lpg-api
   sudo systemctl start caddy
   ```

### Dockerを使用する場合

```bash
# イメージのビルド
docker build -t lpg:latest .

# コンテナの起動
docker run -d \
  --name lpg \
  -p 80:80 \
  -p 443:443 \
  -p 8443:8443 \
  -v /etc/lpg:/etc/lpg \
  -v /var/log/lpg:/var/log/lpg \
  lpg:latest
```

## 設定

### 基本設定（/etc/lpg/config.json）

```json
{
  "hostdomains": {
    "example.com": "192.168.234.0/24"
  },
  "hostingdevice": {
    "example.com": {
      "/app": {
        "deviceip": "192.168.234.10",
        "port": [3000],
        "sitename": "webapp",
        "ips": ["any"]
      }
    }
  }
}
```

詳細な設定方法は [docs/基本仕様書.md](docs/基本仕様書.md) を参照してください。

## 管理UI

ブラウザで `https://<LPG-IP>:8443` にアクセスします。

初期ログイン情報：
- ユーザー名: `lacisadmin`
- パスワード: `changeme` （初回ログイン時に変更必須）

### 主な機能

- **Domains**: ドメインとサブネットの管理
- **Devices**: ルーティングルールの設定
- **Logs**: アクセスログのリアルタイム表示
- **Network**: システムメトリクスとネットワーク状態
- **Settings**: 詳細設定とバックアップ管理

## 開発

### ディレクトリ構造

```
/LPG
├── docs/           # ドキュメント
├── src/
│   ├── api/        # Go APIサーバー
│   ├── web/        # React フロントエンド
│   └── services/   # バックグラウンドサービス
├── config/         # 設定ファイル
├── scripts/        # インストール・管理スクリプト
└── tests/          # テストコード
```

### 開発環境のセットアップ

```bash
# APIサーバー（ホットリロード）
go install github.com/cosmtrek/air@latest
air

# フロントエンド（開発サーバー）
npm run dev
```

### テスト

```bash
# Go テスト
go test ./...

# JavaScript テスト
npm test

# E2Eテスト
npm run test:e2e
```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。
詳細は [LICENSE](LICENSE) ファイルを参照してください。

## 貢献

プルリクエストを歓迎します！
大きな変更を行う場合は、まずIssueを作成して変更内容について議論してください。

## サポート

- 📧 Email: support@lacis.dev
- 💬 Discord: [LacisProxy Community](https://discord.gg/lacis)
- 📖 Wiki: [GitHub Wiki](https://github.com/lacis/lpg/wiki)

---

Made with ❤️ by Lacis Team 