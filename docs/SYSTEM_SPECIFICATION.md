---
title: LacisProxyGateway
projects:
- LPG
tags:
- '#proj-lpg'
created: '2025-07-28'
updated: '2025-08-05'
author: LACIS Team
status: production
---
# LacisProxyGateway

**― Orange Pi Zero 3 ベース「リバースプロキシ＋管理UI」アプライアンス 詳細仕様書 ―**
作成日 : 2025‑07‑26
更新日 : 2025-08-05

---

## 1. 目的と全体像

| 項目        | 内容                                                                                                               |
| --------- | ---------------------------------------------------------------------------------------------------------------- |
| 名称        | **LacisProxyGateway (LPG)**                                                                                      |
| 目的        | Omada SDN 直下に置き、<br>① 外部 HTTP/HTTPS/WebSocket トラフィックを全て収容<br>② DDNS ホスト名・パスでローカル機器へ振り分け<br>③ 管理UIによる設定・監視の一元化 |
| ハード       | Orange Pi Zero 3 (H618 / 4 GB RAM)                                                        |
| OS        | Orange Pi 1.0.2 Jammy (Ubuntu 22.04 arm64)<br>Disk Image: Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img |
| 主要コンポーネント | **nginx**（HTTPS終端 & リバースプロキシ）<br>**Flask**（管理UI）<br>**Python 3.10+**（プロキシサーバー）                             |
| UI        | 内蔵 Flask サーバー（ポート 8443）<br>統一されたダークテーマUI                                                  |
| 可搬構成      | 設定は **JSON ファイル** で管理                                                                               |

---

## 2. ネットワーク設計

```
                 ┌─────────── WAN (ISP) ────────────┐
                 ▼                                  │
          ┌──────────────┐        (CG‑NAT可)        │
          │  Omada GW    │ 192.168.3.1/24  (vlan1)  │
          │ (ER7206 等)  │───────────────────────────┤
          └─────┬────────┘                          │
                │ DNAT 80/443 → 192.168.234.2       │
vlan1            │                                  │
(192.168.3.0/24) │                                  │
─────────────────┘                                  │
         (許可: → vlan555 のみ)                     │
                                                    │
       ┌────────────────────────────────────────────┤
vlan555│            192.168.234.0/24 「lacisstack」 │
        ╞═══════════════════════════════════════════╡
        │ Orange Pi Zero 3 = **LacisProxyGateway** │
        │  • IP: 192.168.234.2                      │
        │  • nginx :80/443 (外向け)                 │
        │  • Admin UI :8443 (Flask)                 │
        │  • プロキシパス: /lpg-admin/              │
        ╘═══════════════════════════════════════════╡
                ▲                                  │
                │  接続先デバイス                   │
                │                                  │
           他 vlan555 デバイス                      │
           (192.168.234.10 - LacisDrawBoards等)     │
```

### 2.1 VLANポリシー管理

**重要**: VLANアクセス制御とポリシールーティングは**Omadaクラウドコントローラー**で一元管理します。

* **vlan555 → vlan1 は禁止**
  Omada ACL（アクセス制御リスト）で設定
* **vlan1 → vlan555 は 80/443 (＋必要 WS ポート) のみ許可**
  Omada ACLで設定

---

## 3. ソフトウェア構成

| レイヤ      | コンポーネント                     | バージョン              | 主な設定                                                 |
| -------- | --------------------------- | ------------------ | ---------------------------------------------------- |
| OS       | Orange Pi 1.0.2 Jammy | Ubuntu 22.04 base  | ARM64アーキテクチャ                              |
| リバースプロキシ | **nginx 1.18.0**               | Ubuntu標準       | SSL終端、プロキシパス設定 |
| 管理UI    | **Flask 2.x + Python 3.10**               | lpg_admin.py       | ポート8443、JWT認証 |
| UIテーマ   | 統一ダークテーマ       | Bootstrap 5 + カスタムCSS | GitHub風デザイン                                 |
| データ可視化       | D3.js  | v7               | トポロジービジュアライゼーション  |
| SSL証明書    | Let's Encrypt                 | certbot            | 自動更新設定                              |

---

## 4. 設定ファイル仕様

### 4.1 nginx設定（`/etc/nginx/sites-available/lpg-ssl`）

```nginx
server {
    listen 443 ssl;
    server_name akb001yebraxfqsm9y.dyndns-web.com;

    ssl_certificate /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/privkey.pem;

    # LPG Admin UI
    location /lpg-admin/ {
        proxy_pass http://127.0.0.1:8443/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # URL重複を防ぐ
        rewrite ^/lpg-admin/lpg-admin/(.*)$ /lpg-admin/$1 permanent;
        
        # リダイレクト処理
        proxy_redirect / /lpg-admin/;
        proxy_redirect http://127.0.0.1:8443/ /lpg-admin/;
        proxy_redirect https://127.0.0.1:8443/ https://$host/lpg-admin/;
    }

    # LacisDrawBoards
    location /lacisstack/boards/ {
        proxy_pass http://192.168.234.10:80/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4.2 デバイス設定（`/opt/lpg/src/devices.json`）

```json
{
  "devices": [
    {
      "id": "device-001",
      "name": "OrangePi 5+",
      "ip": "192.168.234.10",
      "port": 80,
      "path": "/",
      "domain": "lacisstack.boards",
      "status": "active",
      "description": "Main server",
      "type": "server"
    },
    {
      "id": "device-002",
      "name": "whiteboard",
      "ip": "192.168.234.10",
      "port": 80,
      "path": "/whiteboard",
      "domain": "whiteboard",
      "status": "active",
      "description": "Whiteboard application",
      "type": "application"
    }
  ]
}
```

---

## 5. 管理 UI

### 5.1 UI構成

| 項目 | 要件                                                                             |
| -- | ------------------------------------------------------------------------------ |
| 認証 | ユーザー名/パスワード + セッションベース認証                                           |
| 配色 | 統一されたダークテーマ（GitHub風）                                           |
| ナビゲーション | 左サイドバー：**Topology / Domains / Devices / Network / Logs / Settings**                       |
| 機能 | - デバイスのCRUD操作<br>- リアルタイムログビュー<br>- ネットワークトポロジー表示<br>- システム設定管理 |

### 5.2 主要ページ

1. **Topology** - ネットワーク構成の視覚化（D3.js）
2. **Domains** - ドメイン管理
3. **Devices** - デバイス管理（追加/編集/削除）
4. **Network** - ネットワーク状態監視
5. **Logs** - システムログ表示
6. **Settings** - システム設定

---

## 6. API仕様

### 6.1 認証API

- `POST /login` - ログイン
- `GET /logout` - ログアウト

### 6.2 デバイス管理API

- `GET /api/devices` - デバイス一覧
- `POST /api/devices` - デバイス追加
- `PUT /api/device/<device_id>` - デバイス更新
- `DELETE /api/device/<device_id>` - デバイス削除
- `GET /api/device/<device_id>/ping` - デバイスping確認

### 6.3 システム管理API

- `GET /api/metrics` - システムメトリクス
- `GET /api/logs` - ログ取得
- `GET /api/domains` - ドメイン一覧

---

## 7. セキュリティポリシー

1. **HTTPS強制**
   - Let's Encrypt証明書による暗号化
   - HTTP→HTTPSリダイレクト

2. **認証必須**
   - 全管理機能へのアクセスに認証が必要
   - セッションタイムアウト実装

3. **最小権限実行**
   - 必要最小限のポート開放
   - プロセスの非root実行

4. **定期更新**
   - システムパッケージの自動更新
   - SSL証明書の自動更新

---

## 8. デプロイメント

### 8.1 ディレクトリ構成

```
/opt/lpg/
├── src/                    # アプリケーションソース
│   ├── lpg_admin.py       # Flask管理UI
│   ├── templates/         # HTMLテンプレート
│   ├── config.json        # プロキシ設定
│   ├── devices.json       # デバイス情報
│   └── config.py          # Flask設定
├── backups/               # バックアップ
│   └── v1.0_YYYYMMDD/    # バージョンバックアップ
└── logs/                  # ログファイル
```

### 8.2 起動方法

```bash
# LPG管理UIの起動
cd /opt/lpg/src
python3 lpg_admin.py

# または systemdサービスとして
systemctl start lpg-admin
systemctl enable lpg-admin
```

---

## 9. 運用・保守

### 9.1 バックアップ

- 設定ファイルの定期バックアップ
- バージョン管理（v1.0形式）
- リモートバックアップ推奨

### 9.2 モニタリング

- システムログの監視
- リソース使用率の確認
- エラーログの定期確認

### 9.3 トラブルシューティング

- 502 Bad Gateway: LPGサービスの確認
- URL重複: nginx設定の確認
- 認証エラー: セッション状態の確認

---

## 10. 今後の拡張計画

| 機能                       | 概要                                         |
| --------------------------- | ------------------------------------------ |
| **WebSocket統合**           | リアルタイム通信の強化                         |
| **メトリクスダッシュボード** | Prometheus/Grafana統合      |
| **多要素認証**              | セキュリティ強化のための2FA実装 |
| **API拡張**                 | RESTful API の完全実装          |
| **国際化対応**              | 多言語サポート             |

---

### まとめ

LPG v1.0は、Orange Pi Zero 3上で動作する軽量で高機能なリバースプロキシゲートウェイです。統一されたダークテーマUIにより、直感的な操作でネットワーク管理が可能です。外部URLアクセスにも完全対応し、セキュアで拡張性の高いシステムを実現しています。