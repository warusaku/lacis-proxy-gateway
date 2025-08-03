---
title: LPG HTTPS設定ドキュメント
created: '2025-08-02'
updated: '2025-08-02'
author: claudecode
tags:
- '#proj-lpg'
- '#security'
- '#https'
- '#nginx'
---

# LPG HTTPS設定ドキュメント

## 概要

LacisProxyGateway (LPG) にHTTPS対応を実装しました。Let's Encrypt証明書を使用した安全な接続が可能になりました。

## アクセスURL

### HTTPS（推奨）
```
https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/
```

### HTTP（自動リダイレクト）
```
http://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/
```

## 技術仕様

### SSL/TLS証明書
- **発行元**: Let's Encrypt
- **証明書パス**: `/etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/`
- **有効期限**: 2025年10月31日
- **自動更新**: Certbot systemd timerで12時間ごとに確認

### nginxサーバー設定

#### ポート構成
- **80 (HTTP)**: 
  - IPアドレス直接: HTTP接続維持
  - ドメイン経由: HTTPSへ301リダイレクト
- **443 (HTTPS)**: SSL/TLS暗号化接続

#### SSL/TLS設定
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_stapling on;
ssl_stapling_verify on;
```

### セキュリティヘッダー
- `Strict-Transport-Security`: max-age=63072000
- `X-Frame-Options`: DENY
- `X-Content-Type-Options`: nosniff
- `X-XSS-Protection`: 1; mode=block
- `Referrer-Policy`: no-referrer-when-downgrade

### プロキシ設定
- **フロントエンド**: → 192.168.234.10:5173
- **バックエンドAPI**: → 192.168.234.10:8080
- **WebSocket**: → 192.168.234.10:8081

## 管理コマンド

### nginxサービス
```bash
# 設定確認
nginx -t

# 再起動
systemctl restart nginx

# ステータス確認
systemctl status nginx
```

### SSL証明書管理
```bash
# 証明書情報確認
certbot certificates

# 手動更新
certbot renew

# 更新テスト
certbot renew --dry-run
```

### ログ確認
```bash
# アクセスログ
tail -f /var/log/nginx/lacisstack-boards.access.log

# エラーログ
tail -f /var/log/nginx/lacisstack-boards.error.log
```

## トラブルシューティング

### 証明書エラーが出る場合
1. 証明書の有効期限を確認
   ```bash
   openssl x509 -in /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/cert.pem -text -noout | grep "Not After"
   ```

2. Certbotの自動更新を確認
   ```bash
   systemctl status certbot.timer
   ```

### アクセスできない場合
1. nginxが起動しているか確認
   ```bash
   systemctl is-active nginx
   ```

2. ポートが開いているか確認
   ```bash
   ss -tlnp | grep -E ':80|:443'
   ```

3. ファイアウォール設定確認
   ```bash
   iptables -L -n | grep -E '80|443'
   ```

## バックアップとリストア

### 設定のバックアップ
```bash
# nginx設定
cp /etc/nginx/sites-available/lacisstack-boards.conf /backup/

# SSL証明書
tar -czf /backup/letsencrypt-$(date +%Y%m%d).tar.gz /etc/letsencrypt/
```

### リストア手順
1. nginx設定を復元
2. Let's Encrypt設定を復元
3. nginxを再起動

## 今後の改善提案

1. **HTTP/3 (QUIC) 対応**
   - より高速な接続を実現

2. **証明書の監視**
   - 有効期限アラートの設定

3. **レート制限**
   - DDoS対策の強化

4. **ログ解析**
   - アクセス分析ツールの導入