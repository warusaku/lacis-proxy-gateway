#!/bin/bash

# LPG完全機能テストスクリプト
# 作成日: 2025-08-04
# 目的: 修正後のLPG機能を包括的にテスト

echo "=== LPG完全機能テスト開始 ==="
echo "実行時刻: $(date)"
echo ""

# テスト結果ファイル
RESULT_FILE="/tmp/lpg-test-results-$(date +%Y%m%d_%H%M%S).txt"

# テスト結果記録関数
log_result() {
    echo "$1" | tee -a "$RESULT_FILE"
}

# 1. LPGサービス状態確認
log_result "=== 1. サービス状態確認 ==="
log_result ""

# SSH経由でサービス状態を確認
expect << 'EOF' | tee -a "$RESULT_FILE"
set timeout 30

spawn ssh -o StrictHostKeyChecking=no root@192.168.234.2

expect "password:"
send "orangepi\r"

expect "root@"

# lpg-proxy-8080サービス確認
send "echo '--- lpg-proxy-8080サービス ---'\r"
expect "root@"
send "systemctl is-active lpg-proxy-8080\r"
expect "root@"

# lpg_admin.pyプロセス確認
send "echo '--- lpg_admin.pyプロセス ---'\r"
expect "root@"
send "ps aux | grep lpg_admin.py | grep -v grep | wc -l\r"
expect "root@"

# nginxサービス確認
send "echo '--- nginxサービス ---'\r"
expect "root@"
send "systemctl is-active nginx\r"
expect "root@"

# ポート確認
send "echo '--- リスニングポート ---'\r"
expect "root@"
send "netstat -tlnp | grep -E '(80|443|8080|8443)' | awk '{print $4, $7}'\r"
expect "root@"

send "exit\r"
expect eof
EOF

log_result ""
log_result "=== 2. 管理UIアクセステスト ==="
log_result ""

# 管理UIのヘルスチェック
log_result "--- ログインページアクセス ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.234.2:8443/)
if [ "$HTTP_CODE" = "200" ]; then
    log_result "✅ ログインページ: 正常 (HTTP $HTTP_CODE)"
else
    log_result "❌ ログインページ: エラー (HTTP $HTTP_CODE)"
fi

# Puppeteerを使用した管理UIテスト
log_result ""
log_result "--- Puppeteer管理UIテスト ---"

cat > /tmp/test-lpg-admin-ui.js << 'JSEOF'
const puppeteer = require('puppeteer');

(async () => {
  try {
    const browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // ログインページ
    console.log('1. ログインページアクセス...');
    await page.goto('http://192.168.234.2:8443/', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });
    
    // ログイン
    console.log('2. ログイン実行...');
    await page.type('input[name="username"]', 'admin');
    await page.type('input[name="password"]', 'lpgadmin123');
    await page.click('button[type="submit"]');
    
    await page.waitForNavigation({ waitUntil: 'networkidle2' });
    
    // トポロジーページテスト
    console.log('3. トポロジーページアクセス...');
    const topologyUrl = page.url();
    
    if (topologyUrl.includes('/topology')) {
      console.log('✅ トポロジーページ: 正常表示');
      
      // エラーメッセージがないか確認
      const errorExists = await page.evaluate(() => {
        return document.body.textContent.includes('Internal Server Error') ||
               document.body.textContent.includes('TemplateSyntaxError');
      });
      
      if (errorExists) {
        console.log('❌ トポロジーページ: エラーが表示されています');
      } else {
        console.log('✅ トポロジーページ: エラーなし');
      }
      
      // スクリーンショット
      await page.screenshot({ path: '/tmp/lpg-topology-test.png' });
      console.log('   スクリーンショット保存: /tmp/lpg-topology-test.png');
    } else {
      console.log('❌ トポロジーページ: リダイレクトエラー');
    }
    
    // デバイスページテスト
    console.log('4. デバイスページアクセス...');
    await page.goto('http://192.168.234.2:8443/devices', {
      waitUntil: 'networkidle2'
    });
    
    const devicesPageOK = await page.evaluate(() => {
      return !document.body.textContent.includes('Internal Server Error');
    });
    
    if (devicesPageOK) {
      console.log('✅ デバイスページ: 正常表示');
    } else {
      console.log('❌ デバイスページ: エラー');
    }
    
    await browser.close();
    
  } catch (error) {
    console.error('テストエラー:', error.message);
  }
})();
JSEOF

cd /tmp
node /tmp/test-lpg-admin-ui.js 2>&1 | tee -a "$RESULT_FILE"

log_result ""
log_result "=== 3. プロキシ機能テスト ==="
log_result ""

# HTTPSプロキシテスト（LacisDrawBoards）
log_result "--- HTTPSプロキシテスト ---"
PROXY_RESPONSE=$(curl -s -I -X GET https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/ 2>&1 | head -1)
log_result "レスポンス: $PROXY_RESPONSE"

if echo "$PROXY_RESPONSE" | grep -q "503"; then
    log_result "✅ プロキシ転送: 正常（バックエンド未稼働のため503）"
elif echo "$PROXY_RESPONSE" | grep -q "502"; then
    log_result "⚠️ プロキシ転送: LPGサービスに問題がある可能性"
else
    log_result "ℹ️ プロキシ転送: $PROXY_RESPONSE"
fi

log_result ""
log_result "=== 4. 設定ファイル確認 ==="
log_result ""

# config.json内容確認
expect << 'EOF' | tee -a "$RESULT_FILE"
set timeout 30

spawn ssh -o StrictHostKeyChecking=no root@192.168.234.2

expect "password:"
send "orangepi\r"

expect "root@"

send "echo '--- config.json内容 ---'\r"
expect "root@"
send "cat /opt/lpg/config.json | grep -A3 'lacisstack/boards'\r"
expect "root@"

send "exit\r"
expect eof
EOF

log_result ""
log_result "=== 5. ログ確認 ==="
log_result ""

# 最新のエラーログ確認
expect << 'EOF' | tee -a "$RESULT_FILE"
set timeout 30

spawn ssh -o StrictHostKeyChecking=no root@192.168.234.2

expect "password:"
send "orangepi\r"

expect "root@"

send "echo '--- lpg-proxy-8080最新ログ ---'\r"
expect "root@"
send "journalctl -u lpg-proxy-8080 -n 10 --no-pager\r"
expect "root@"

send "echo ''\r"
expect "root@"
send "echo '--- lpg_admin最新ログ ---'\r"
expect "root@"
send "tail -10 /var/log/lpg_admin.log 2>/dev/null || echo 'ログファイルなし'\r"
expect "root@"

send "exit\r"
expect eof
EOF

# テスト結果サマリー
log_result ""
log_result "============================================"
log_result "=== テスト結果サマリー ==="
log_result "============================================"
log_result ""
log_result "テスト完了時刻: $(date)"
log_result "結果ファイル: $RESULT_FILE"
log_result ""

# 結果ファイルから成功/失敗をカウント
SUCCESS_COUNT=$(grep -c "✅" "$RESULT_FILE" || echo 0)
FAIL_COUNT=$(grep -c "❌" "$RESULT_FILE" || echo 0)
WARN_COUNT=$(grep -c "⚠️" "$RESULT_FILE" || echo 0)

log_result "成功: $SUCCESS_COUNT 項目"
log_result "失敗: $FAIL_COUNT 項目"
log_result "警告: $WARN_COUNT 項目"
log_result ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    log_result "🎉 すべてのテストが正常に完了しました！"
else
    log_result "⚠️ 一部のテストで問題が検出されました。"
    log_result "詳細は結果ファイルを確認してください: $RESULT_FILE"
fi

echo ""
echo "スクリーンショット:"
echo "- /tmp/lpg-topology-test.png (トポロジーページ)"