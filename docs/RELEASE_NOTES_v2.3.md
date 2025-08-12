# LPG v2.3 Release Notes

**Release Date:** 2025-08-12  
**Version:** 2.3  
**Backup:** `lpg_backup_20250812_v2.3.tar.gz` (サーバー内 `/opt/` およびローカル `backups/` に保存)

## 🎯 Overview

LPG管理UIの重要な不具合修正とログ機能の改善を実施しました。Bootstrap 5への完全移行とデバッグログ機能の強化により、システムの安定性と保守性が向上しました。

## 🛠 Fixed Issues

### 1. タブ切り替え機能の修復
- **問題:** Bootstrap 4から5への移行により、タブ切り替えが動作しない
- **原因:** `data-toggle` 属性がBootstrap 5で `data-bs-toggle` に変更
- **修正:** 
  - `logs_unified.html`: すべてのタブ関連属性を Bootstrap 5 形式に更新
  - `base_unified.html`: Bootstrap 5 JavaScriptの正しい読み込み順序を設定

### 2. デバッグログ記録機能の修復
- **問題:** デバッグログが記録されない
- **原因:** 
  - `/var/log/lpg_debug.log` ファイルが存在しない
  - `datetime.datetime.now()` のインポートエラー
- **修正:** 
  - ログファイルの自動作成機能を追加
  - datetime インポートを修正

### 3. ログインページスパムの解消
- **問題:** 5秒ごとに「Login page accessed」ログが大量記録
- **原因:** 自動更新によるAPIリダイレクトが繰り返しログを生成
- **修正:** 
  - ログインページアクセスログを完全に削除
  - ログイン成功/失敗のみを記録するように変更

## ✨ New Features

### 1. JST タイムゾーン対応
- デバッグログのタイムスタンプを JST (Asia/Tokyo) に変更
- より直感的なログ監視が可能に

### 2. 起動/シャットダウンログの強化
```
============================================================
LPG Admin Service Starting
Working directory: /opt/lpg/src
Bind address configured: 127.0.0.1:8443
Configuration loaded: X domains, Y devices
Flask application initializing
============================================================
```

### 3. ログイン監査ログの実装
- ログイン成功: `[INFO] Login successful: user=admin from xxx.xxx.xxx.xxx`
- ログイン失敗: `[WARNING] Login failed: user=baduser from xxx.xxx.xxx.xxx`

## 📝 Modified Files

### Core Files
- `src/lpg_admin.py` - デバッグログ機能、ログイン処理の改善
- `src/templates/logs_unified.html` - Bootstrap 5対応、タブ機能修復
- `src/templates/base_unified.html` - Bootstrap 5 JavaScript設定

### JavaScript Changes
- 正規表現エラーの修正: `logContent.match(/\n/g)` → `logContent.split('\n').length`
- エスケープ文字の修正: `\!confirm` → `!confirm`
- 自動更新間隔の変更: 5秒 → 30秒

## 🔧 Technical Details

### Bootstrap Migration
```html
<!-- Before (Bootstrap 4) -->
<a class="nav-link" data-toggle="tab" href="#debug-logs">

<!-- After (Bootstrap 5) -->
<a class="nav-link" data-bs-toggle="tab" href="#debug-logs">
```

### Debug Log Improvements
```python
# JST timezone support
import pytz
jst = pytz.timezone('Asia/Tokyo')
timestamp = datetime.now(jst).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]

# Login logging (only errors and success)
if username in users and password_hash == stored_hash:
    write_debug_log(f'Login successful: user={username} from {request.remote_addr}', 'INFO')
else:
    write_debug_log(f'Login failed: user={username} from {request.remote_addr}', 'WARNING')
```

## 📦 Backup Information

### Server Backup
- Location: `/opt/lpg_backup_20250812_v2.3.tar.gz`
- Size: 415KB
- Content: Complete `/opt/lpg/` directory including all configurations

### Local Backup
- Location: `backups/lpg_backup_20250812_v2.3.tar.gz`
- Identical copy of server backup for disaster recovery

## 🚀 Deployment

システムは現在本番環境で稼働中：
- URL: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/
- Server: 192.168.234.2 (VLAN 555)
- Port: 8443 (HTTPS)
- Bind: 127.0.0.1 (ローカルバインドで安全性確保)

## ⚠️ Known Issues

現在、既知の問題はありません。

## 📌 Notes

- デバッグログは最大500KBで自動ローテーション
- ログインスパムの完全解消により、ログファイルサイズが大幅に削減
- Bootstrap 5への完全移行が完了

---

*This release has been thoroughly tested in production environment.*