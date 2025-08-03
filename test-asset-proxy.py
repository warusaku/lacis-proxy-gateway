#!/usr/bin/env python3
"""
LPG Proxy Asset Path Test Script
アセットパスが正しく処理されるかテストします
"""

import urllib.request
import urllib.error
import sys
import time

def test_proxy_endpoint(url, description):
    """プロキシエンドポイントをテストする"""
    print(f"\n[TEST] {description}")
    print(f"URL: {url}")
    
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'LPG-Asset-Test/1.0')
        
        with urllib.request.urlopen(req, timeout=10) as response:
            content_type = response.headers.get('Content-Type', 'unknown')
            content_length = len(response.read())
            
            print(f"✅ Status: {response.getcode()}")
            print(f"✅ Content-Type: {content_type}")
            print(f"✅ Content-Length: {content_length} bytes")
            
            if response.getcode() == 200:
                return True
            return False
            
    except urllib.error.HTTPError as e:
        print(f"❌ HTTP Error: {e.code} {e.reason}")
        return False
    except urllib.error.URLError as e:
        print(f"❌ URL Error: {e.reason}")
        return False
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def main():
    print("=== LPG Proxy Asset Path Test ===")
    
    # テスト対象のURL
    tests = [
        {
            'url': 'http://192.168.234.10/health',
            'description': 'LPG Proxy Health Check'
        },
        {
            'url': 'http://192.168.234.10/lacisstack/boards/',
            'description': 'Main Board Page'
        },
        {
            'url': 'http://192.168.234.10/lacisstack/boards/assets/index-CVPzGGZm.js',
            'description': 'JavaScript Asset File'
        },
        {
            'url': 'http://192.168.234.10/lacisstack/boards/assets/index-gfaUftBN.css',
            'description': 'CSS Asset File'
        },
        {
            'url': 'http://192.168.234.2:80/lacisstack/boards/',
            'description': 'Direct Target Server - Main Page'
        },
        {
            'url': 'http://192.168.234.2:80/lacisstack/boards/assets/index-CVPzGGZm.js',
            'description': 'Direct Target Server - JavaScript Asset'
        }
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test_proxy_endpoint(test['url'], test['description']):
            passed += 1
        time.sleep(1)  # Rate limiting
    
    print(f"\n=== Test Results ===")
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 All tests passed! Asset proxy is working correctly.")
        sys.exit(0)
    else:
        print("⚠️  Some tests failed. Check the output above for details.")
        sys.exit(1)

if __name__ == '__main__':
    main()