#!/bin/bash

# Directory to scan (use current if not specified)
TARGET_DIR="${1:-.}"

# Ensure dependencies exist
command -v openssl >/dev/null 2>&1 || { echo >&2 "OpenSSL is required. Install via brew install openssl"; exit 1; }
command -v keytool >/dev/null 2>&1 || { echo >&2 "keytool (from Java) is required."; exit 1; }

echo "Scanning directory: $TARGET_DIR"
echo

# Function to check cert/key details
check_openssl_cert() {
    local file="$1"
    echo "==> Checking $file"
    
    openssl x509 -in "$file" -noout -text 2>/dev/null | awk '
        /Signature Algorithm:/ { print "Signature Algorithm: " $0 }
        /Public-Key:/ { getline; print "Key Length: " $1 }
    '
    echo
}

check_openssl_key() {
    local file="$1"
    echo "==> Checking Private Key $file"
    
    openssl rsa -in "$file" -check -noout -text 2>/dev/null | awk '
        /Private-Key:/ { print "Private Key Length: " $0 }
    '
    echo
}

check_p12() {
    local file="$1"
    echo "==> Checking PKCS#12 $file"
    
    openssl pkcs12 -in "$file" -nodes -passin pass:atakatak 2>/dev/null | openssl x509 -noout -text 2>/dev/null | awk '
        /Signature Algorithm:/ { print "Signature Algorithm: " $0 }
        /Public-Key:/ { getline; print "Key Length: " $1 }
    '
    echo
}

check_jks() {
    local file="$1"
    echo "==> Checking JKS $file"
    
    keytool -list -keystore "$file" -storepass atakatak -v 2>/dev/null | awk '
        /Signature algorithm name:/ { print "Signature Algorithm: " $0 }
        /Certificate chain length:/ { print }
        /Public key:/ { getline; print "Key Algorithm: " $0 }
    '
    echo
}

# Loop through files
find "$TARGET_DIR" -type f \( -iname "*.cer" -o -iname "*.pem" -o -iname "*.key" -o -iname "*.p12" -o -iname "*.jks" \) | while read -r file; do
    case "$file" in
        *.cer|*.pem)
            check_openssl_cert "$file"
            ;;
        *.key)
            check_openssl_key "$file"
            ;;
        *.p12)
            check_p12 "$file"
            ;;
        *.jks)
            check_jks "$file"
            ;;
        *)
            echo "Unknown file type: $file"
            ;;
    esac
done

