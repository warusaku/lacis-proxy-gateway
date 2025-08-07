# LPG トラブルシューティングガイド

## 一般的な問題と解決方法

### 1. 502 Bad Gateway エラー

#### 症状
- nginxが「502 Bad Gateway」エラーを返す
- 外部URLからLPG管理UIにアクセスできない

#### 原因と解決方法

**1. LPGサービスが停止している**
```bash
# サービス状態確認
systemctl status lpg-admin

# 停止している場合は起動
systemctl start lpg-admin

# ログ確認
tail -30 /var/log/lpg_admin.log
```

**2. ポート番号の不一致**
```bash
# LPGが使用しているポート確認
netstat -tlnp | grep python

# nginx設定確認
grep proxy_pass /etc/nginx/sites-enabled/lpg-ssl
```

**3. Pythonプロセスがクラッシュ**
```bash
# プロセス確認
ps aux | grep lpg_admin

# 手動で起動してエラー確認
cd /opt/lpg/src
python3 lpg_admin.py
```

### 2. ログインできない

#### 症状
- 正しいユーザー名/パスワードを入力してもログインできない
- ログイン後すぐにログアウトされる

#### 解決方法

**1. Cookieの問題**
- ブラウザのCookieとキャッシュをクリア
- プライベートブラウジングモードで試す
- 別のブラウザで試す

**2. セッションの問題**
```bash
# LPGを再起動
systemctl restart lpg-admin

# ログでエラーを確認
grep -i error /var/log/lpg_admin.log | tail -20
```

**3. 認証情報の確認**
- デフォルト: admin / lpgadmin123
- 大文字小文字を確認

### 3. 外部URLアクセスの問題

#### 症状
- https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/ にアクセスできない
- ローカルではアクセスできるが外部からアクセスできない

#### 解決方法

**1. DNS解決の確認**
```bash
# DNSが正しく解決されているか確認
nslookup akb001yebraxfqsm9y.dyndns-web.com

# pingテスト
ping akb001yebraxfqsm9y.dyndns-web.com
```

**2. SSL証明書の確認**
```bash
# 証明書の有効期限確認
certbot certificates

# 証明書の更新
certbot renew --dry-run
```

**3. nginx設定の確認**
```bash
# 設定テスト
nginx -t

# エラーログ確認
tail -f /var/log/nginx/error.log
```

### 4. サイドバーナビゲーションが動作しない

#### 症状
- サイドバーのリンクをクリックしても404エラー
- URL重複（/lpg-admin/lpg-admin/）

#### 解決方法

**1. テンプレートの確認**
```bash
# テンプレートファイルの存在確認
ls -la /opt/lpg/src/templates/*_unified.html

# base_unified.htmlのリンク確認
grep href /opt/lpg/src/templates/base_unified.html
```

**2. nginx rewriteルールの確認**
```bash
# 重複防止ルールが設定されているか確認
grep rewrite /etc/nginx/sites-enabled/lpg-ssl
```

### 5. デバイス管理機能の問題

#### 症状
- デバイスの追加・削除ができない
- デバイス一覧が表示されない

#### 解決方法

**1. devices.jsonの確認**
```bash
# ファイルの存在と権限確認
ls -la /opt/lpg/src/devices.json

# JSON形式の確認
python3 -m json.tool /opt/lpg/src/devices.json
```

**2. APIエンドポイントの確認**
```bash
# ローカルでAPIテスト
curl -s http://localhost:8443/api/devices
```

### 6. パフォーマンスの問題

#### 症状
- レスポンスが遅い
- タイムアウトエラーが発生する

#### 解決方法

**1. システムリソースの確認**
```bash
# CPU使用率
top

# メモリ使用量
free -h

# ディスク使用量
df -h
```

**2. プロセスの最適化**
```bash
# 不要なサービスの停止
systemctl list-units --type=service --state=running

# LPGプロセスの優先度調整
renice -n -5 $(pgrep -f lpg_admin.py)
```

### 7. ログが記録されない

#### 症状
- /var/log/lpg_admin.logが空または存在しない
- エラーが発生してもログに記録されない

#### 解決方法

```bash
# ログファイルの作成と権限設定
touch /var/log/lpg_admin.log
touch /var/log/lpg_access.log
chmod 644 /var/log/lpg_*.log

# systemdサービスのログ設定確認
grep StandardOutput /etc/systemd/system/lpg-admin.service

# journalctlでログ確認
journalctl -u lpg-admin -f
```

### 8. SSL関連の問題

#### 症状
- HTTPSでアクセスできない
- 証明書エラーが表示される

#### 解決方法

```bash
# Let's Encrypt証明書の状態確認
certbot certificates

# 証明書の手動更新
certbot renew --force-renewal

# nginx SSL設定の確認
nginx -t
```

## デバッグモード

### 詳細なデバッグ情報を取得

```bash
# LPGをデバッグモードで起動
cd /opt/lpg/src
export FLASK_DEBUG=1
python3 lpg_admin.py

# nginxのデバッグログ有効化
# /etc/nginx/nginx.confに追加
error_log /var/log/nginx/error.log debug;
```

## ログファイルの場所

- **LPG管理UI**: `/var/log/lpg_admin.log`
- **LPGアクセスログ**: `/var/log/lpg_access.log`
- **nginx アクセスログ**: `/var/log/nginx/access.log`
- **nginx エラーログ**: `/var/log/nginx/error.log`
- **systemd ジャーナル**: `journalctl -u lpg-admin`

## 緊急時の対処

### 完全リセット

```bash
# サービス停止
systemctl stop lpg-admin
systemctl stop nginx

# 設定バックアップ
cp -r /opt/lpg/src /opt/lpg/src.backup.$(date +%Y%m%d)

# サービス再起動
systemctl start nginx
systemctl start lpg-admin
```

### リカバリー

```bash
# バックアップから復元
cd /opt/lpg
tar -xzf backups/v1.0_20250805.tar.gz

# サービス再起動
systemctl restart lpg-admin
```

## サポート連絡先

上記の方法で解決しない場合は、以下の情報を含めてシステム管理者に連絡してください：

1. エラーメッセージの全文
2. 発生時刻
3. 実行した操作
4. 関連ログファイルの内容
5. システム情報（`uname -a`の出力）