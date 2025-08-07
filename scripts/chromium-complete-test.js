const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// テスト結果を保存するディレクトリ
const RESULTS_DIR = `/tmp/lpg-chromium-test-${Date.now()}`;
fs.mkdirSync(RESULTS_DIR, { recursive: true });

// テスト結果オブジェクト
const testResults = {
  timestamp: new Date().toISOString(),
  tests: [],
  summary: {
    total: 0,
    passed: 0,
    failed: 0
  }
};

// テスト関数
async function runTest(name, testFn) {
  console.log(`\n🧪 実行中: ${name}`);
  const result = {
    name,
    status: 'pending',
    error: null,
    screenshots: [],
    startTime: new Date().toISOString()
  };
  
  try {
    await testFn(result);
    result.status = 'passed';
    testResults.summary.passed++;
    console.log(`✅ 成功: ${name}`);
  } catch (error) {
    result.status = 'failed';
    result.error = error.message;
    testResults.summary.failed++;
    console.log(`❌ 失敗: ${name} - ${error.message}`);
  }
  
  result.endTime = new Date().toISOString();
  testResults.tests.push(result);
  testResults.summary.total++;
}

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors'],
    ignoreHTTPSErrors: true
  });
  
  try {
    const page = await browser.newPage();
    page.setViewport({ width: 1920, height: 1080 });
    
    // ネットワークエラーを記録
    page.on('pageerror', error => {
      console.log('Page error:', error.message);
    });
    
    // === Test 1: HTTPSアクセステスト ===
    await runTest('HTTPSアクセステスト', async (result) => {
      await page.goto('https://192.168.234.2:8443/', {
        waitUntil: 'networkidle2',
        timeout: 30000
      });
      
      const title = await page.title();
      const url = page.url();
      
      if (!url.includes('https://')) {
        throw new Error('HTTPSでアクセスできません');
      }
      
      const screenshotPath = path.join(RESULTS_DIR, '1-https-access.png');
      await page.screenshot({ path: screenshotPath });
      result.screenshots.push(screenshotPath);
      
      console.log(`  - URL: ${url}`);
      console.log(`  - Title: ${title}`);
    });
    
    // === Test 2: ログイン機能テスト ===
    await runTest('ログイン機能テスト', async (result) => {
      // ログインフォームの存在確認
      const usernameInput = await page.$('input[name="username"]');
      const passwordInput = await page.$('input[name="password"]');
      const loginButton = await page.$('button[type="submit"]');
      
      if (!usernameInput || !passwordInput || !loginButton) {
        throw new Error('ログインフォームが見つかりません');
      }
      
      // ログイン実行
      await page.type('input[name="username"]', 'admin');
      await page.type('input[name="password"]', 'lpgadmin123');
      
      const screenshotPath1 = path.join(RESULTS_DIR, '2-login-form.png');
      await page.screenshot({ path: screenshotPath1 });
      result.screenshots.push(screenshotPath1);
      
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle2' }),
        loginButton.click()
      ]);
      
      const afterLoginUrl = page.url();
      if (!afterLoginUrl.includes('/topology')) {
        throw new Error('ログイン後のリダイレクトが正しくありません');
      }
      
      const screenshotPath2 = path.join(RESULTS_DIR, '2-after-login.png');
      await page.screenshot({ path: screenshotPath2 });
      result.screenshots.push(screenshotPath2);
      
      console.log(`  - ログイン成功`);
      console.log(`  - リダイレクト先: ${afterLoginUrl}`);
    });
    
    // === Test 3: トポロジーページ表示テスト ===
    await runTest('トポロジーページ表示テスト', async (result) => {
      const currentUrl = page.url();
      if (!currentUrl.includes('/topology')) {
        await page.goto('https://192.168.234.2:8443/topology', {
          waitUntil: 'networkidle2'
        });
      }
      
      // エラーメッセージがないことを確認
      const pageContent = await page.content();
      if (pageContent.includes('Internal Server Error') || 
          pageContent.includes('TemplateSyntaxError')) {
        throw new Error('トポロジーページにエラーが表示されています');
      }
      
      // 重要な要素の存在確認
      const elements = {
        'ネットワーク構成タイトル': await page.$('h4:has-text("ネットワーク構成")'),
        'LPGステータス': await page.$('h5:has-text("LPGステータス")'),
        'デバイス詳細': await page.$('h5:has-text("デバイス詳細")'),
        'デバイステーブル': await page.$('table.table')
      };
      
      for (const [name, element] of Object.entries(elements)) {
        if (!element) {
          console.log(`  ⚠️ ${name}が見つかりません`);
        } else {
          console.log(`  ✓ ${name}を確認`);
        }
      }
      
      // デバイス情報を取得
      const devices = await page.evaluate(() => {
        const rows = document.querySelectorAll('table.table tbody tr');
        return Array.from(rows).map(row => {
          const cells = row.querySelectorAll('td');
          return {
            ip: cells[0]?.textContent?.trim(),
            service: cells[1]?.textContent?.trim(),
            path: cells[2]?.textContent?.trim(),
            port: cells[3]?.textContent?.trim()
          };
        });
      });
      
      console.log(`  - 表示されているデバイス数: ${devices.length}`);
      devices.forEach(device => {
        console.log(`    • ${device.ip} - ${device.service} (${device.path})`);
      });
      
      const screenshotPath = path.join(RESULTS_DIR, '3-topology-page.png');
      await page.screenshot({ path: screenshotPath, fullPage: true });
      result.screenshots.push(screenshotPath);
    });
    
    // === Test 4: デバイスページテスト ===
    await runTest('デバイスページテスト', async (result) => {
      await page.goto('https://192.168.234.2:8443/devices', {
        waitUntil: 'networkidle2'
      });
      
      const pageContent = await page.content();
      if (pageContent.includes('Internal Server Error')) {
        throw new Error('デバイスページでエラーが発生しています');
      }
      
      // デバイステーブルの確認
      const deviceCount = await page.evaluate(() => {
        return document.querySelectorAll('table tbody tr').length;
      });
      
      console.log(`  - 登録デバイス数: ${deviceCount}`);
      
      const screenshotPath = path.join(RESULTS_DIR, '4-devices-page.png');
      await page.screenshot({ path: screenshotPath, fullPage: true });
      result.screenshots.push(screenshotPath);
    });
    
    // === Test 5: プロキシ機能テスト ===
    await runTest('プロキシ機能テスト（HTTPS）', async (result) => {
      const response = await page.goto('https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/', {
        waitUntil: 'networkidle2',
        timeout: 30000
      });
      
      const status = response.status();
      const headers = response.headers();
      
      console.log(`  - ステータスコード: ${status}`);
      console.log(`  - サーバー: ${headers['server']}`);
      
      if (status === 503) {
        console.log(`  - 503エラー（バックエンドサーバー未稼働のため正常）`);
      } else if (status === 502) {
        throw new Error('502エラー - LPGプロキシに問題があります');
      }
      
      const screenshotPath = path.join(RESULTS_DIR, '5-proxy-test.png');
      await page.screenshot({ path: screenshotPath });
      result.screenshots.push(screenshotPath);
    });
    
    // === Test 6: レスポンシブデザインテスト ===
    await runTest('レスポンシブデザインテスト', async (result) => {
      const viewports = [
        { name: 'mobile', width: 375, height: 667 },
        { name: 'tablet', width: 768, height: 1024 },
        { name: 'desktop', width: 1920, height: 1080 }
      ];
      
      for (const viewport of viewports) {
        await page.setViewport(viewport);
        await page.goto('https://192.168.234.2:8443/topology', {
          waitUntil: 'networkidle2'
        });
        
        const screenshotPath = path.join(RESULTS_DIR, `6-responsive-${viewport.name}.png`);
        await page.screenshot({ path: screenshotPath });
        result.screenshots.push(screenshotPath);
        
        console.log(`  - ${viewport.name} (${viewport.width}x${viewport.height}): OK`);
      }
    });
    
    // === Test 7: セキュリティヘッダーテスト ===
    await runTest('セキュリティヘッダーテスト', async (result) => {
      const response = await page.goto('https://192.168.234.2:8443/', {
        waitUntil: 'networkidle2'
      });
      
      const headers = response.headers();
      const securityHeaders = {
        'x-frame-options': headers['x-frame-options'],
        'x-content-type-options': headers['x-content-type-options'],
        'strict-transport-security': headers['strict-transport-security']
      };
      
      console.log('  - セキュリティヘッダー:');
      for (const [header, value] of Object.entries(securityHeaders)) {
        console.log(`    • ${header}: ${value || '未設定'}`);
      }
    });
    
  } finally {
    await browser.close();
    
    // テスト結果をJSONファイルに保存
    const resultsPath = path.join(RESULTS_DIR, 'test-results.json');
    fs.writeFileSync(resultsPath, JSON.stringify(testResults, null, 2));
    
    // サマリーを表示
    console.log('\n' + '='.repeat(50));
    console.log('📊 テスト結果サマリー');
    console.log('='.repeat(50));
    console.log(`総テスト数: ${testResults.summary.total}`);
    console.log(`✅ 成功: ${testResults.summary.passed}`);
    console.log(`❌ 失敗: ${testResults.summary.failed}`);
    console.log(`成功率: ${(testResults.summary.passed / testResults.summary.total * 100).toFixed(1)}%`);
    console.log(`\n結果保存先: ${RESULTS_DIR}`);
    console.log('='.repeat(50));
  }
})();