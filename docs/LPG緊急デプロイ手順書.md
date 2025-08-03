# LPG緊急デプロイ手順書

作成日: 2025-08-03
目的: LacisDrawBoardsのReact初期化問題を解決するためのLPG設定更新

## 1. 現在の問題

- **キャッシュ問題**: LPGが1時間キャッシュで古いファイル（index-B1C70Nyd.js）を配信
- **正しいファイル**: Orange Piでは新しいファイル（index-CVPzGGZm.js）が配信されている
- **WebUI問題**: DeployChangeボタンがログインボタンと重なっている

## 2. 緊急実施事項

### 2.1 LPGサーバー（192.168.234.2）での作業

#### Step 1: 現在の設定をバックアップ
```bash
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
```

#### Step 2: キャッシュクリア
```bash
# Caddyのキャッシュディレクトリをクリア
sudo rm -rf /var/cache/caddy/*
```

#### Step 3: 新しいCaddyfile適用

以下の内容を `/etc/caddy/Caddyfile` に設定：

```caddy
# 簡素化されたCaddyfile - キャッシュ無効
{
    admin localhost:2019
    log {
        output file /var/log/lpg/caddy.log
        format json
        level INFO
    }
}

# HTTPからHTTPSへのリダイレクト
:80 {
    redir https://{host}{uri} permanent
}

# メインドメイン設定
https://akb001yebraxfqsm9y.dyndns-web.com {
    
    # LacisDrawBoards - キャッシュ無効
    handle /lacisstack/boards* {
        uri strip_prefix /lacisstack/boards
        reverse_proxy 192.168.234.10:8080 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Prefix /lacisstack/boards
            
            # キャッシュ無効化ヘッダー
            header_down Cache-Control "no-cache, no-store, must-revalidate"
            header_down Pragma "no-cache"
            header_down Expires "0"
        }
    }
    
    # デフォルトレスポンス
    handle {
        respond "LacisProxyGateway" 200
    }
    
    # アクセスログ
    log {
        output file /var/log/lpg/access.log
        format json
    }
}

# 管理UI
:8443 {
    reverse_proxy localhost:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    log {
        output file /var/log/lpg/admin-access.log
        format json
    }
}
```

#### Step 4: 設定の検証と適用
```bash
# 設定の検証
sudo caddy validate --config /etc/caddy/Caddyfile

# Caddyの再起動
sudo systemctl restart caddy

# ステータス確認
sudo systemctl status caddy
```

#### Step 5: 動作確認
```bash
# HTTPSアクセステスト
curl -v https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/ | grep index-

# 正しいファイル名（index-CVPzGGZm.js）が返されることを確認
```

## 3. WebUI修正（後日実施）

### 3.1 DeployChangeボタンの修正

Flask版のbase.htmlで以下の修正：
```html
<!-- 削除すべき行 -->
<div style="position: fixed; top: 12px; right: 24px; z-index: 9999;">
    <button id="deployBtn" onclick="deployChanges()" class="btn btn-primary">
        <i class="bi bi-rocket-takeoff"></i>
        Deploy Changes
    </button>
</div>
```

### 3.2 React版への統一
- Flask Templates（/src/templates/）を段階的に廃止
- React SPA（/src/web/）に統一

## 4. 確認項目

### 4.1 キャッシュクリア後の確認
- [ ] `https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/`で新しいJS（index-CVPzGGZm.js）が配信される
- [ ] Reactアプリケーションが正常に初期化される
- [ ] 白い画面ではなく、LacisDrawBoardsのUIが表示される

### 4.2 ブラウザ側での確認
```
1. Ctrl+Shift+R でハードリロード
2. 開発者ツール（F12）でNetworkタブを確認
3. index-CVPzGGZm.js が200 OKで読み込まれていることを確認
```

## 5. トラブルシューティング

### 5.1 まだ古いファイルが返される場合
```bash
# ブラウザキャッシュのクリア
# Chrome: 設定 → プライバシーとセキュリティ → 閲覧履歴データの削除

# DNSキャッシュのクリア（Windows）
ipconfig /flushdns

# DNSキャッシュのクリア（Mac）
sudo dscacheutil -flushcache
```

### 5.2 Caddyが起動しない場合
```bash
# エラーログ確認
sudo journalctl -u caddy -n 50

# 設定ファイルの構文チェック
sudo caddy validate --config /etc/caddy/Caddyfile

# 手動起動でエラー確認
sudo caddy run --config /etc/caddy/Caddyfile
```

## 6. 連絡先

問題が発生した場合：
- LPG管理者に連絡
- バックアップファイルから復元可能

## 7. 注意事項

- **セキュリティヘッダーは削除**: 各サービス（LacisDrawBoards）側で適切に設定すること
- **キャッシュは完全無効化**: パフォーマンスよりも正確性を優先
- **将来的な最適化**: 問題解決後、適切なキャッシュ設定を再検討