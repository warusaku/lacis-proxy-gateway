const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Create test results directory
const resultsDir = `test-results-${new Date().toISOString().replace(/:/g, '-')}`;
if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir);
}

class LacisDrawBoardsTester {
    constructor() {
        this.browser = null;
        this.testResults = {
            timestamp: new Date().toISOString(),
            production: {
                url: 'https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/',
                status: 'pending',
                httpStatus: null,
                redirects: [],
                errors: [],
                websockets: [],
                authentication: {
                    required: false,
                    oauth: false,
                    redirectUrl: null
                },
                pageLoad: {
                    success: false,
                    loadTime: null,
                    domReady: false
                }
            },
            local: {
                url: 'http://localhost:5173/lacisstack/boards/',
                status: 'pending',
                httpStatus: null,
                errors: [],
                websockets: [],
                serverRunning: false
            },
            issues: [],
            recommendations: []
        };
    }

    async init() {
        console.log('🚀 Starting LacisDrawBoards Comprehensive Test Suite');
        console.log('=' .repeat(80));
        console.log(`Test Started: ${new Date().toLocaleString()}`);
        console.log('=' .repeat(80));

        this.browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--ignore-certificate-errors',
                '--disable-web-security'
            ]
        });
    }

    async testProductionURL() {
        console.log('\n📍 Testing Production URL');
        console.log('-'.repeat(60));
        
        const page = await this.browser.newPage();
        const startTime = Date.now();
        
        try {
            // Set up error monitoring
            const jsErrors = [];
            page.on('pageerror', error => {
                jsErrors.push({
                    message: error.message,
                    stack: error.stack,
                    timestamp: new Date().toISOString()
                });
            });

            page.on('console', msg => {
                if (msg.type() === 'error') {
                    jsErrors.push({
                        type: 'console-error',
                        message: msg.text(),
                        timestamp: new Date().toISOString()
                    });
                }
            });

            // Monitor network requests for redirects
            const redirects = [];
            page.on('response', response => {
                if (response.status() >= 300 && response.status() < 400) {
                    redirects.push({
                        from: response.url(),
                        to: response.headers()['location'],
                        status: response.status()
                    });
                }
            });

            // Monitor WebSocket connections
            const cdp = await page.target().createCDPSession();
            await cdp.send('Network.enable');
            
            const websockets = [];
            cdp.on('Network.webSocketCreated', (params) => {
                websockets.push({
                    url: params.url,
                    requestId: params.requestId,
                    initiator: params.initiator,
                    timestamp: new Date().toISOString(),
                    status: 'created'
                });
                console.log(`   🔌 WebSocket connection created: ${params.url}`);
            });

            cdp.on('Network.webSocketFrameReceived', (params) => {
                const ws = websockets.find(w => w.requestId === params.requestId);
                if (ws) {
                    ws.status = 'active';
                    ws.lastMessageReceived = new Date().toISOString();
                }
            });

            cdp.on('Network.webSocketFrameError', (params) => {
                const ws = websockets.find(w => w.requestId === params.requestId);
                if (ws) {
                    ws.status = 'error';
                    ws.error = params.errorMessage;
                }
            });

            cdp.on('Network.webSocketClosed', (params) => {
                const ws = websockets.find(w => w.requestId === params.requestId);
                if (ws) {
                    ws.status = 'closed';
                    ws.closedAt = new Date().toISOString();
                }
            });

            // Attempt to load the page
            console.log(`   🌐 Navigating to: ${this.testResults.production.url}`);
            
            const response = await page.goto(this.testResults.production.url, {
                waitUntil: 'networkidle2',
                timeout: 30000
            });

            const loadTime = Date.now() - startTime;
            
            this.testResults.production.httpStatus = response.status();
            this.testResults.production.pageLoad.loadTime = loadTime;
            this.testResults.production.pageLoad.success = response.ok();
            
            console.log(`   ✅ Page loaded with status: ${response.status()} in ${loadTime}ms`);
            
            // Check final URL for authentication redirect
            const finalUrl = page.url();
            console.log(`   📍 Final URL: ${finalUrl}`);
            
            if (finalUrl !== this.testResults.production.url) {
                this.testResults.production.redirects = redirects;
                
                if (finalUrl.includes('oauth') || finalUrl.includes('auth') || finalUrl.includes('login')) {
                    this.testResults.production.authentication.required = true;
                    this.testResults.production.authentication.oauth = finalUrl.includes('oauth');
                    this.testResults.production.authentication.redirectUrl = finalUrl;
                    console.log(`   🔐 Authentication required - redirected to: ${finalUrl}`);
                    
                    // Check for OAuth provider
                    if (finalUrl.includes('lacis')) {
                        console.log(`   🔑 LacisOAuth detected`);
                    }
                }
            }

            // Wait for any dynamic content
            await new Promise(resolve => setTimeout(resolve, 3000));

            // Check DOM ready state
            const domReady = await page.evaluate(() => document.readyState === 'complete');
            this.testResults.production.pageLoad.domReady = domReady;

            // Look for application elements
            const appElements = await page.evaluate(() => {
                return {
                    canvas: !!document.querySelector('canvas'),
                    svg: !!document.querySelector('svg'),
                    drawingArea: !!document.querySelector('[class*="board"], [class*="canvas"], [class*="draw"], [id*="board"], [id*="canvas"]'),
                    loginForm: !!document.querySelector('form[action*="login"], form[action*="auth"], #loginForm, .login-form'),
                    oauthButtons: document.querySelectorAll('button[onclick*="oauth"], a[href*="oauth"], .oauth-button').length
                };
            });

            console.log(`   📋 Page Elements Found:`);
            console.log(`      - Canvas: ${appElements.canvas ? '✅' : '❌'}`);
            console.log(`      - SVG: ${appElements.svg ? '✅' : '❌'}`);
            console.log(`      - Drawing Area: ${appElements.drawingArea ? '✅' : '❌'}`);
            console.log(`      - Login Form: ${appElements.loginForm ? '✅' : '❌'}`);
            console.log(`      - OAuth Buttons: ${appElements.oauthButtons > 0 ? `✅ (${appElements.oauthButtons})` : '❌'}`);

            // Store errors and websockets
            this.testResults.production.errors = jsErrors;
            this.testResults.production.websockets = websockets;
            
            if (jsErrors.length > 0) {
                console.log(`   ⚠️  Found ${jsErrors.length} JavaScript errors`);
                jsErrors.forEach((error, idx) => {
                    console.log(`      ${idx + 1}. ${error.message || error.type}`);
                });
            }

            if (websockets.length > 0) {
                console.log(`   🔌 WebSocket connections: ${websockets.length}`);
                websockets.forEach((ws, idx) => {
                    console.log(`      ${idx + 1}. ${ws.url} - Status: ${ws.status}`);
                });
            } else {
                console.log(`   ⚠️  No WebSocket connections detected`);
            }

            // Take screenshot
            await page.screenshot({ 
                path: path.join(resultsDir, 'Production (HTTPS).png'), 
                fullPage: true 
            });

            this.testResults.production.status = 'completed';
            
        } catch (error) {
            console.log(`   ❌ Error testing production: ${error.message}`);
            this.testResults.production.status = 'failed';
            this.testResults.production.errors.push({
                type: 'navigation-error',
                message: error.message,
                stack: error.stack
            });
            this.testResults.issues.push({
                severity: 'critical',
                area: 'production',
                description: `Failed to load production URL: ${error.message}`
            });
        } finally {
            await page.close();
        }
    }

    async testLocalDevelopment() {
        console.log('\n📍 Testing Local Development Server');
        console.log('-'.repeat(60));
        
        const page = await this.browser.newPage();
        
        try {
            // First check if the server is running
            console.log(`   🌐 Checking local server at: ${this.testResults.local.url}`);
            
            const response = await page.goto(this.testResults.local.url, {
                waitUntil: 'domcontentloaded',
                timeout: 5000
            }).catch(err => null);

            if (response) {
                this.testResults.local.serverRunning = true;
                this.testResults.local.httpStatus = response.status();
                console.log(`   ✅ Local server is running - Status: ${response.status()}`);
                
                // Monitor errors
                const jsErrors = [];
                page.on('pageerror', error => jsErrors.push(error.message));
                page.on('console', msg => {
                    if (msg.type() === 'error') {
                        jsErrors.push(msg.text());
                    }
                });

                await new Promise(resolve => setTimeout(resolve, 2000));
                this.testResults.local.errors = jsErrors;
                
                if (jsErrors.length > 0) {
                    console.log(`   ⚠️  Found ${jsErrors.length} JavaScript errors on local`);
                }

                // Take screenshot
                await page.screenshot({ 
                    path: path.join(resultsDir, 'Local Dev Server.png'), 
                    fullPage: true 
                });

                this.testResults.local.status = 'running';
            } else {
                this.testResults.local.serverRunning = false;
                this.testResults.local.status = 'not-running';
                console.log(`   ⚠️  Local development server is not running on port 5173`);
                this.testResults.issues.push({
                    severity: 'medium',
                    area: 'local',
                    description: 'Local development server is not running on port 5173'
                });
            }
            
        } catch (error) {
            console.log(`   ❌ Error checking local server: ${error.message}`);
            this.testResults.local.status = 'error';
            this.testResults.local.errors.push(error.message);
        } finally {
            await page.close();
        }
    }

    async testLPGProxy() {
        console.log('\n📍 Testing LPG Proxy Connection');
        console.log('-'.repeat(60));
        
        const page = await this.browser.newPage();
        
        try {
            // Test HTTP to HTTPS redirect
            console.log(`   🔄 Testing HTTP to HTTPS redirect...`);
            const httpUrl = 'http://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/';
            
            const response = await page.goto(httpUrl, {
                waitUntil: 'domcontentloaded',
                timeout: 10000
            }).catch(err => null);

            if (response) {
                const finalUrl = page.url();
                if (finalUrl.startsWith('https://')) {
                    console.log(`   ✅ HTTP to HTTPS redirect working`);
                } else {
                    console.log(`   ⚠️  No HTTPS redirect detected`);
                    this.testResults.issues.push({
                        severity: 'high',
                        area: 'security',
                        description: 'HTTP to HTTPS redirect not working properly'
                    });
                }
            }

            // Test LPG proxy on port 8080
            console.log(`   🔌 Testing LPG proxy on port 8080...`);
            const proxyResponse = await page.goto('http://127.0.0.1:8080', {
                waitUntil: 'domcontentloaded',
                timeout: 5000
            }).catch(err => null);

            if (proxyResponse && proxyResponse.ok()) {
                console.log(`   ✅ LPG proxy is responding on port 8080`);
                await page.screenshot({ 
                    path: path.join(resultsDir, 'Local Proxy.png'), 
                    fullPage: true 
                });
            } else {
                console.log(`   ⚠️  LPG proxy not responding on port 8080`);
                this.testResults.issues.push({
                    severity: 'high',
                    area: 'proxy',
                    description: 'LPG proxy not responding on port 8080'
                });
            }

        } catch (error) {
            console.log(`   ❌ Error testing proxy: ${error.message}`);
        } finally {
            await page.close();
        }
    }

    analyzeResults() {
        console.log('\n📊 Analysis and Recommendations');
        console.log('=' .repeat(80));

        // Analyze production issues
        if (this.testResults.production.status === 'failed') {
            this.testResults.recommendations.push({
                priority: 'critical',
                action: 'Fix production URL accessibility',
                details: 'The production URL is not accessible. Check nginx configuration and SSL certificates.'
            });
        }

        if (this.testResults.production.authentication.required && !this.testResults.production.authentication.oauth) {
            this.testResults.recommendations.push({
                priority: 'high',
                action: 'Configure OAuth integration',
                details: 'Authentication is required but OAuth integration may not be properly configured.'
            });
        }

        if (this.testResults.production.websockets.length === 0) {
            this.testResults.recommendations.push({
                priority: 'medium',
                action: 'Check WebSocket configuration',
                details: 'No WebSocket connections detected. Verify nginx WebSocket proxy configuration.'
            });
        }

        if (this.testResults.production.errors.length > 0) {
            this.testResults.recommendations.push({
                priority: 'high',
                action: 'Fix JavaScript errors',
                details: `Found ${this.testResults.production.errors.length} JavaScript errors that need to be resolved.`
            });
        }

        // Analyze local development
        if (!this.testResults.local.serverRunning) {
            this.testResults.recommendations.push({
                priority: 'low',
                action: 'Start local development server',
                details: 'Local development server is not running. Run: npm run dev'
            });
        }

        // Print summary
        console.log('\n🎯 Key Findings:');
        console.log('-'.repeat(40));
        
        console.log('\n✅ Working:');
        if (this.testResults.production.pageLoad.success) {
            console.log('   • Production URL is accessible');
        }
        if (this.testResults.production.authentication.oauth) {
            console.log('   • OAuth redirect is functioning');
        }
        if (this.testResults.production.websockets.some(ws => ws.status === 'active')) {
            console.log('   • WebSocket connections are active');
        }

        console.log('\n❌ Issues Found:');
        this.testResults.issues.forEach(issue => {
            console.log(`   • [${issue.severity.toUpperCase()}] ${issue.description}`);
        });

        console.log('\n💡 Recommendations:');
        this.testResults.recommendations.forEach(rec => {
            console.log(`   • [${rec.priority.toUpperCase()}] ${rec.action}`);
            console.log(`     ${rec.details}`);
        });
    }

    async generateReport() {
        // Save JSON report
        const jsonPath = path.join(resultsDir, 'test-results.json');
        fs.writeFileSync(jsonPath, JSON.stringify(this.testResults, null, 2));
        console.log(`\n📄 JSON report saved: ${jsonPath}`);

        // Generate HTML report
        const htmlReport = `
<!DOCTYPE html>
<html>
<head>
    <title>LacisDrawBoards Test Report</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .section { 
            background: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .status-success { color: #4CAF50; font-weight: bold; }
        .status-failed { color: #f44336; font-weight: bold; }
        .status-warning { color: #ff9800; font-weight: bold; }
        .issue { 
            padding: 10px;
            margin: 10px 0;
            border-left: 4px solid #f44336;
            background: #ffebee;
        }
        .recommendation {
            padding: 10px;
            margin: 10px 0;
            border-left: 4px solid #2196F3;
            background: #e3f2fd;
        }
        .metadata { color: #666; font-size: 14px; }
        pre { 
            background: #f4f4f4;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th { background: #f0f0f0; }
    </style>
</head>
<body>
    <h1>🔍 LacisDrawBoards Test Report</h1>
    <div class="metadata">Generated: ${this.testResults.timestamp}</div>

    <div class="section">
        <h2>Production Environment</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>URL</td><td>${this.testResults.production.url}</td></tr>
            <tr><td>HTTP Status</td><td class="${this.testResults.production.httpStatus === 200 ? 'status-success' : 'status-failed'}">${this.testResults.production.httpStatus || 'N/A'}</td></tr>
            <tr><td>Load Time</td><td>${this.testResults.production.pageLoad.loadTime}ms</td></tr>
            <tr><td>Authentication Required</td><td>${this.testResults.production.authentication.required ? 'Yes' : 'No'}</td></tr>
            <tr><td>OAuth Configured</td><td>${this.testResults.production.authentication.oauth ? 'Yes' : 'No'}</td></tr>
            <tr><td>WebSocket Connections</td><td>${this.testResults.production.websockets.length}</td></tr>
            <tr><td>JavaScript Errors</td><td class="${this.testResults.production.errors.length > 0 ? 'status-failed' : 'status-success'}">${this.testResults.production.errors.length}</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>Local Development</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>URL</td><td>${this.testResults.local.url}</td></tr>
            <tr><td>Server Running</td><td class="${this.testResults.local.serverRunning ? 'status-success' : 'status-warning'}">${this.testResults.local.serverRunning ? 'Yes' : 'No'}</td></tr>
            <tr><td>HTTP Status</td><td>${this.testResults.local.httpStatus || 'N/A'}</td></tr>
            <tr><td>JavaScript Errors</td><td>${this.testResults.local.errors.length}</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>Issues Found</h2>
        ${this.testResults.issues.length === 0 ? '<p class="status-success">No issues found!</p>' : 
          this.testResults.issues.map(issue => `
            <div class="issue">
                <strong>[${issue.severity.toUpperCase()}]</strong> ${issue.area}: ${issue.description}
            </div>
          `).join('')}
    </div>

    <div class="section">
        <h2>Recommendations</h2>
        ${this.testResults.recommendations.length === 0 ? '<p>No recommendations at this time.</p>' :
          this.testResults.recommendations.map(rec => `
            <div class="recommendation">
                <strong>[${rec.priority.toUpperCase()}]</strong> ${rec.action}<br>
                <small>${rec.details}</small>
            </div>
          `).join('')}
    </div>

    <div class="section">
        <h2>JavaScript Errors Detail</h2>
        ${this.testResults.production.errors.length === 0 ? '<p class="status-success">No JavaScript errors detected.</p>' :
          '<pre>' + JSON.stringify(this.testResults.production.errors, null, 2) + '</pre>'}
    </div>

    <div class="section">
        <h2>WebSocket Connections</h2>
        ${this.testResults.production.websockets.length === 0 ? '<p class="status-warning">No WebSocket connections detected.</p>' :
          '<pre>' + JSON.stringify(this.testResults.production.websockets, null, 2) + '</pre>'}
    </div>
</body>
</html>
        `;

        const htmlPath = path.join(resultsDir, 'report.html');
        fs.writeFileSync(htmlPath, htmlReport);
        console.log(`📄 HTML report saved: ${htmlPath}`);
    }

    async cleanup() {
        if (this.browser) {
            await this.browser.close();
        }
    }

    async run() {
        try {
            await this.init();
            await this.testProductionURL();
            await this.testLocalDevelopment();
            await this.testLPGProxy();
            this.analyzeResults();
            await this.generateReport();
            
            console.log('\n' + '=' .repeat(80));
            console.log('✅ Test Suite Completed Successfully');
            console.log(`📁 Results saved in: ${resultsDir}/`);
            console.log('=' .repeat(80));
            
        } catch (error) {
            console.error('\n❌ Test suite failed:', error);
        } finally {
            await this.cleanup();
        }
    }
}

// Execute the test
const tester = new LacisDrawBoardsTester();
tester.run().catch(console.error);