---
title: LacisProxyGateway WebUI仕様書
projects:
- LPG
tags:
- '#proj-lpg'
created: '2025-07-28'
updated: '2025-07-28'
author: unknown
status: draft
---
# LacisProxyGateway WebUI仕様書

**― 管理インターフェース詳細設計書 ―**  
作成日: 2025-07-26  
バージョン: 1.0.0

---

## 1. 概要

### 1.1 基本情報

| 項目 | 内容 |
|------|------|
| システム名 | LacisProxyGateway 管理UI |
| URL | https://192.168.234.2:8443 |
| フレームワーク | React 18 + TypeScript |
| UIライブラリ | Primer CSS / GitHub Design System |
| 状態管理 | React Context API + useReducer |
| ビルドツール | Vite |
| 認証方式 | JWT (HS256) + Argon2id |

### 1.2 対応ブラウザ

- Chrome 100+ (推奨)
- Firefox 100+
- Safari 15+
- Edge 100+

---

## 2. 画面構成

### 2.1 レイアウト構造

```
┌─────────────────────────────────────────────────────────┐
│ Header                                                  │
│ ┌─────────┬───────────────────────────────────────────┐ │
│ │         │                                           │ │
│ │ Sidebar │           Main Content Area              │ │
│ │         │                                           │ │
│ │  250px  │            Responsive                     │ │
│ │         │                                           │ │
│ └─────────┴───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 2.2 共通コンポーネント

#### Header
- ロゴ: "LacisProxyGateway"
- ステータス表示: システム稼働状態
- テーマ切替: Light/Dark (GitHub Dark - Primer Teal)
- ユーザーメニュー: ログアウト、パスワード変更
- Deployボタン: 設定変更の適用（右上固定）

#### Sidebar
- ナビゲーションメニュー
  - 🌐 Domains
  - 📱 Devices
  - 📊 Logs
  - 🔌 Network
  - ⚙️ Settings
- 折りたたみ可能（レスポンシブ対応）

---

## 3. 画面詳細

### 3.1 ログイン画面

**パス**: `/login`

**フィールド**:
- ユーザー名（テキスト）
- パスワード（パスワード）
- ログイン維持（チェックボックス）

**機能**:
- JWT発行（有効期限: デフォルト24時間）
- 初回ログイン時はパスワード変更を強制
- 3回失敗で5分間ロック

### 3.2 Domains画面

**パス**: `/domains`

**表示内容**:
- ドメイン一覧（カード形式）
  - ドメイン名
  - 許可サブネット
  - 登録パス数
  - ステータス（有効/無効）

**機能**:
- ドメイン追加/編集/削除
- 証明書状態確認
- DNSレコード確認（オプション）

**追加フォーム**:
```
ドメイン名: [________________]
許可サブネット: [________________] (例: 192.168.234.0/24)
[追加] [キャンセル]
```

### 3.3 Devices画面

**パス**: `/devices`

**表示内容**:
- ルーティングルール一覧（テーブル形式）
  - ドメイン
  - パス
  - 転送先IP
  - ポート
  - サイト名
  - 許可IP
  - アクセス数（24h）

**機能**:
- ルール追加/編集/削除
- パスベースのルーティング設定
- 一括インポート/エクスポート（JSON）

**ルール編集モード**:
- フォームモード: 各フィールド個別入力
- JSONモード: Monaco Editorで直接編集

### 3.4 Logs画面

**パス**: `/logs`

**表示内容**:
- アクセスログ（リアルタイム更新）
  - タイムスタンプ（JST）
  - ホスト名
  - パス
  - 送信元IP
  - メソッド
  - ステータスコード
  - レスポンスサイズ
  - サイト名

**機能**:
- フィルタリング（ドメイン、ステータス、期間）
- 検索（全文検索）
- エクスポート（CSV/JSON）
- ログレベル切替

### 3.5 Network画面

**パス**: `/network`

**表示内容**:
- ネットワーク設定
  - IPアドレス設定
  - VLANポリシー表示
  - ポート開放状態
- システムメトリクス
  - CPU使用率
  - メモリ使用率
  - ネットワークトラフィック
  - Caddy統計

**機能**:
- iptablesルール確認
- 接続テスト実行
- パケットキャプチャ（制限付き）

### 3.6 Settings画面

**パス**: `/settings`

**タブ構成**:

#### 基本設定
- 管理者ユーザー管理
- パスワードポリシー設定
- セッションタイムアウト

#### バックアップ
- 設定バックアップ（JSON）
- スケジュール設定
- リストア（最大5世代）

#### ログ設定
- ログサーバーエンドポイント
- 送信間隔
- ローテーション設定

#### 詳細設定
- WebSocketタイムアウト
- 証明書管理
- Caddy設定（上級者向け）

---

## 4. API仕様

### 4.1 認証API

**POST** `/api/auth/login`
```json
Request:
{
  "username": "string",
  "password": "string"
}

Response:
{
  "token": "jwt_token",
  "expiresIn": 86400,
  "requirePasswordChange": false
}
```

### 4.2 設定API

**GET** `/api/config`
- 現在の設定を取得

**PUT** `/api/config`
- 設定を更新（要Deploy）

**POST** `/api/config/deploy`
- 変更を適用

**POST** `/api/config/rollback`
- 前バージョンに戻す

### 4.3 ドメインAPI

**GET** `/api/domains`
**POST** `/api/domains`
**PUT** `/api/domains/{domain}`
**DELETE** `/api/domains/{domain}`

### 4.4 デバイスAPI

**GET** `/api/devices`
**POST** `/api/devices`
**PUT** `/api/devices/{id}`
**DELETE** `/api/devices/{id}`

### 4.5 ログAPI

**GET** `/api/logs`
- クエリパラメータ: from, to, domain, status, limit

**GET** `/api/logs/stream`
- WebSocket接続でリアルタイムログ

### 4.6 システムAPI

**GET** `/api/system/status`
**GET** `/api/system/metrics`
**POST** `/api/system/test`

---

## 5. セキュリティ要件

### 5.1 認証・認可

- すべてのAPIエンドポイントはJWT認証必須
- トークンはhttpOnlyクッキーで管理
- CSRF対策: ダブルサブミットクッキー

### 5.2 通信

- HTTPS必須（自己署名証明書許可）
- HSTS有効化
- Content-Security-Policy設定

### 5.3 入力検証

- すべての入力をサーバー側で検証
- SQLインジェクション対策（パラメータバインド）
- XSS対策（React標準のエスケープ）

---

## 6. エラーハンドリング

### 6.1 エラーコード

| コード | 説明 | 対処 |
|-------|------|------|
| 401 | 認証エラー | 再ログイン |
| 403 | 権限エラー | 権限確認 |
| 409 | 設定競合 | 再読み込み |
| 422 | 検証エラー | 入力確認 |
| 500 | サーバーエラー | サポート連絡 |

### 6.2 エラー表示

- トースト通知（Primer Flash）
- インラインエラー（フォーム）
- エラーページ（システムエラー）

---

## 7. パフォーマンス要件

- 初期読み込み: 3秒以内
- API応答: 1秒以内（ログ除く）
- リアルタイムログ: 100ms遅延以内
- 同時接続: 10セッション

---

## 8. アクセシビリティ

- WAI-ARIA準拠
- キーボードナビゲーション対応
- スクリーンリーダー対応
- 高コントラストモード

---

## 9. 国際化（将来拡張）

- 言語ファイル分離（i18n）
- 日付フォーマット対応
- 初期は日本語のみ

---

## 10. 開発規約

### 10.1 コーディング規約

- ESLint + Prettier使用
- TypeScript strict mode
- 関数コンポーネント使用
- カスタムフック活用

### 10.2 ディレクトリ構造

```
src/web/
├── components/     # 共通コンポーネント
├── pages/         # ページコンポーネント
├── hooks/         # カスタムフック
├── services/      # API通信
├── contexts/      # Context定義
├── types/         # TypeScript型定義
├── utils/         # ユーティリティ
└── styles/        # グローバルスタイル
```

### 10.3 命名規則

- コンポーネント: PascalCase
- ファイル: コンポーネントと同名
- 関数: camelCase
- 定数: UPPER_SNAKE_CASE
- 型: PascalCase + suffix（Type/Interface）

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|-----------|------|----------|--------|
| 1.0.0 | 2025-07-26 | 初版作成 | System |
