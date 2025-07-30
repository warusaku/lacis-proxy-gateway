#!/bin/bash
# generate-certs.sh - Generate self-signed certificates for development
# Version: 1.0.0

set -e

CERT_DIR="./certs"
CERT_DAYS=365
COUNTRY="JP"
STATE="Tokyo"
LOCALITY="Tokyo"
ORGANIZATION="LacisProxyGateway"
ORGANIZATIONAL_UNIT="Development"
COMMON_NAME="localhost"

echo "=== LPG開発用証明書生成スクリプト ==="
echo

# certsディレクトリ作成
if [ ! -d "$CERT_DIR" ]; then
    echo "証明書ディレクトリを作成しています: $CERT_DIR"
    mkdir -p "$CERT_DIR"
fi

# 既存の証明書をチェック
if [ -f "$CERT_DIR/localhost.crt" ] && [ -f "$CERT_DIR/localhost.key" ]; then
    echo "警告: 既存の証明書が見つかりました。"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました。"
        exit 0
    fi
fi

# OpenSSL設定ファイルを生成
cat > "$CERT_DIR/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=$COUNTRY
ST=$STATE
L=$LOCALITY
O=$ORGANIZATION
OU=$ORGANIZATIONAL_UNIT
CN=$COMMON_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = lpg.local
DNS.4 = *.lpg.local
IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 192.168.234.2
EOF

echo "自己署名証明書を生成しています..."

# 秘密鍵の生成
openssl genrsa -out "$CERT_DIR/localhost.key" 2048

# 証明書署名要求（CSR）の生成
openssl req -new -key "$CERT_DIR/localhost.key" \
    -out "$CERT_DIR/localhost.csr" \
    -config "$CERT_DIR/openssl.cnf"

# 自己署名証明書の生成
openssl x509 -req -days $CERT_DAYS \
    -in "$CERT_DIR/localhost.csr" \
    -signkey "$CERT_DIR/localhost.key" \
    -out "$CERT_DIR/localhost.crt" \
    -extensions v3_req \
    -extfile "$CERT_DIR/openssl.cnf"

# クリーンアップ
rm -f "$CERT_DIR/localhost.csr" "$CERT_DIR/openssl.cnf"

# パーミッション設定
chmod 600 "$CERT_DIR/localhost.key"
chmod 644 "$CERT_DIR/localhost.crt"

echo
echo "証明書の生成が完了しました:"
echo "  証明書: $CERT_DIR/localhost.crt"
echo "  秘密鍵: $CERT_DIR/localhost.key"
echo "  有効期限: $CERT_DAYS 日"
echo

# 証明書の情報を表示
echo "証明書情報:"
openssl x509 -in "$CERT_DIR/localhost.crt" -noout -subject -dates

echo
echo "ブラウザでhttps://localhost:8443にアクセスする際は、"
echo "セキュリティ警告を承認してください（開発用証明書のため）。" 