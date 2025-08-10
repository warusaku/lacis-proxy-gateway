const puppeteer = require('puppeteer');

async function testLacisDrawBoards() {
    let browser;
    const testResults = {
        appLoad: { status: 'pending', details: '' },
        authRedirect: { status: 'pending', details: '' },
        whiteboardAccess: { status: 'pending', details: '' },
        jsErrors: { status: 'pending', errors: [] },
        websocketConnections: { status: 'pending', connections: [] },
        drawingFunctionality: { status: 'pending', details: '' }
    };

    try {
        console.log('Starting LacisDrawBoards Test Suite...\n');
        console.log('Target URL: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/');
        console.log('='.repeat(80));

        // Launch browser with debugging options
        browser = await puppeteer.launch({
            headless: false, // Set to false to see the browser
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-web-security',
                '--disable-features=IsolateOrigins,site-per-process'
            ],
            devtools: true // Open devtools automatically
        });

        const page = await browser.newPage();
        
        // Set viewport for desktop testing
        await page.setViewport({ width: 1920, height: 1080 });

        // Collect JavaScript errors
        page.on('pageerror', error => {
            testResults.jsErrors.errors.push({
                message: error.message,
                stack: error.stack
            });
        });

        // Monitor console messages
        page.on('console', msg => {
            if (msg.type() === 'error') {
                testResults.jsErrors.errors.push({
                    type: 'console-error',
                    message: msg.text()
                });
            }
        });

        // Monitor WebSocket connections
        const cdp = await page.target().createCDPSession();
        await cdp.send('Network.enable');
        
        const websocketConnections = [];
        cdp.on('Network.webSocketCreated', (params) => {
            websocketConnections.push({
                url: params.url,
                requestId: params.requestId,
                status: 'created'
            });
        });

        cdp.on('Network.webSocketFrameReceived', (params) => {
            const connection = websocketConnections.find(ws => ws.requestId === params.requestId);
            if (connection) {
                connection.status = 'active';
                connection.lastMessage = params.response.payloadData;
            }
        });

        // Test 1: Application Load
        console.log('\n1. Testing Application Load...');
        try {
            const response = await page.goto('https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/', {
                waitUntil: 'networkidle2',
                timeout: 30000
            });

            testResults.appLoad.status = response.ok() ? 'success' : 'failed';
            testResults.appLoad.details = `HTTP Status: ${response.status()}, URL: ${response.url()}`;
            
            // Take screenshot of initial load
            await page.screenshot({ path: 'test_initial_load.png', fullPage: true });
            
            console.log(`   ✓ Application loaded with status ${response.status()}`);
        } catch (error) {
            testResults.appLoad.status = 'failed';
            testResults.appLoad.details = error.message;
            console.log(`   ✗ Failed to load application: ${error.message}`);
        }

        // Test 2: Authentication Redirect
        console.log('\n2. Testing Authentication Redirect...');
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for any redirects
        
        const currentUrl = page.url();
        if (currentUrl.includes('oauth') || currentUrl.includes('login') || currentUrl.includes('auth')) {
            testResults.authRedirect.status = 'success';
            testResults.authRedirect.details = `Redirected to: ${currentUrl}`;
            console.log(`   ✓ Authentication redirect detected: ${currentUrl}`);
            
            // Try to find and capture login form
            const loginForm = await page.$('form');
            if (loginForm) {
                await page.screenshot({ path: 'test_auth_page.png', fullPage: true });
                console.log('   ✓ Login form found');
            }
        } else if (currentUrl.includes('/boards')) {
            testResults.authRedirect.status = 'not-required';
            testResults.authRedirect.details = 'No authentication redirect - may already be authenticated or not required';
            console.log('   ℹ No authentication redirect occurred');
        } else {
            testResults.authRedirect.status = 'unknown';
            testResults.authRedirect.details = `Current URL: ${currentUrl}`;
            console.log(`   ? Unexpected URL: ${currentUrl}`);
        }

        // Test 3: Whiteboard Interface Access
        console.log('\n3. Testing Whiteboard Interface Access...');
        try {
            // Look for canvas or drawing area elements
            const canvas = await page.$('canvas');
            const svgBoard = await page.$('svg');
            const drawingArea = await page.$('[class*="board"], [class*="canvas"], [class*="draw"], [id*="board"], [id*="canvas"]');
            
            if (canvas || svgBoard || drawingArea) {
                testResults.whiteboardAccess.status = 'success';
                testResults.whiteboardAccess.details = `Found: ${canvas ? 'Canvas' : ''} ${svgBoard ? 'SVG' : ''} ${drawingArea ? 'Drawing Area' : ''}`;
                console.log(`   ✓ Whiteboard interface elements found`);
                
                await page.screenshot({ path: 'test_whiteboard_interface.png', fullPage: true });
            } else {
                testResults.whiteboardAccess.status = 'not-found';
                testResults.whiteboardAccess.details = 'No whiteboard elements detected';
                console.log('   ✗ No whiteboard interface elements found');
            }
        } catch (error) {
            testResults.whiteboardAccess.status = 'error';
            testResults.whiteboardAccess.details = error.message;
            console.log(`   ✗ Error checking whiteboard: ${error.message}`);
        }

        // Test 4: JavaScript Errors
        console.log('\n4. Checking for JavaScript Errors...');
        await new Promise(resolve => setTimeout(resolve, 2000)); // Wait for any async errors
        
        if (testResults.jsErrors.errors.length === 0) {
            testResults.jsErrors.status = 'success';
            console.log('   ✓ No JavaScript errors detected');
        } else {
            testResults.jsErrors.status = 'errors-found';
            console.log(`   ✗ Found ${testResults.jsErrors.errors.length} JavaScript errors:`);
            testResults.jsErrors.errors.forEach((error, index) => {
                console.log(`      ${index + 1}. ${error.message || error.type}`);
            });
        }

        // Test 5: WebSocket Connections
        console.log('\n5. Checking WebSocket Connections...');
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for WebSocket connections
        
        testResults.websocketConnections.connections = websocketConnections;
        if (websocketConnections.length > 0) {
            testResults.websocketConnections.status = 'success';
            console.log(`   ✓ Found ${websocketConnections.length} WebSocket connection(s):`);
            websocketConnections.forEach((ws, index) => {
                console.log(`      ${index + 1}. ${ws.url} - Status: ${ws.status}`);
            });
        } else {
            testResults.websocketConnections.status = 'none-found';
            console.log('   ℹ No WebSocket connections detected');
        }

        // Test 6: Drawing Functionality (if accessible)
        console.log('\n6. Testing Drawing Functionality...');
        try {
            const canvas = await page.$('canvas');
            if (canvas) {
                // Simulate drawing on canvas
                const boundingBox = await canvas.boundingBox();
                if (boundingBox) {
                    // Simulate mouse drawing
                    await page.mouse.move(boundingBox.x + 50, boundingBox.y + 50);
                    await page.mouse.down();
                    await page.mouse.move(boundingBox.x + 150, boundingBox.y + 150);
                    await page.mouse.up();
                    
                    await new Promise(resolve => setTimeout(resolve, 1000));
                    await page.screenshot({ path: 'test_drawing_attempt.png', fullPage: true });
                    
                    testResults.drawingFunctionality.status = 'tested';
                    testResults.drawingFunctionality.details = 'Drawing simulation attempted on canvas';
                    console.log('   ✓ Drawing functionality tested');
                }
            } else {
                // Try clicking on drawing tools if present
                const drawTools = await page.$$('[class*="tool"], [class*="pen"], [class*="brush"], button');
                if (drawTools.length > 0) {
                    testResults.drawingFunctionality.status = 'tools-found';
                    testResults.drawingFunctionality.details = `Found ${drawTools.length} potential drawing tools`;
                    console.log(`   ℹ Found ${drawTools.length} potential drawing tools`);
                } else {
                    testResults.drawingFunctionality.status = 'not-accessible';
                    testResults.drawingFunctionality.details = 'No drawing interface accessible';
                    console.log('   ℹ Drawing functionality not accessible');
                }
            }
        } catch (error) {
            testResults.drawingFunctionality.status = 'error';
            testResults.drawingFunctionality.details = error.message;
            console.log(`   ✗ Error testing drawing: ${error.message}`);
        }

        // Generate final report
        console.log('\n' + '='.repeat(80));
        console.log('TEST RESULTS SUMMARY');
        console.log('='.repeat(80));
        
        console.log('\n📊 Overall Status:');
        Object.entries(testResults).forEach(([test, result]) => {
            const statusIcon = result.status === 'success' ? '✅' : 
                              result.status === 'failed' || result.status === 'error' ? '❌' : 
                              '⚠️';
            console.log(`${statusIcon} ${test}: ${result.status}`);
            if (result.details) {
                console.log(`   Details: ${result.details}`);
            }
        });

        // Save detailed report
        const reportData = {
            timestamp: new Date().toISOString(),
            url: 'https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/',
            testResults: testResults
        };
        
        require('fs').writeFileSync('test_report.json', JSON.stringify(reportData, null, 2));
        console.log('\n📄 Detailed report saved to test_report.json');
        console.log('📸 Screenshots saved: test_initial_load.png, test_auth_page.png, test_whiteboard_interface.png, test_drawing_attempt.png');

    } catch (error) {
        console.error('\n❌ Test suite failed with error:', error.message);
    } finally {
        if (browser) {
            console.log('\nClosing browser in 10 seconds...');
            await new Promise(resolve => setTimeout(resolve, 10000));
            await browser.close();
        }
    }
}

// Run the test
testLacisDrawBoards().catch(console.error);