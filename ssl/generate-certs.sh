#!/bin/bash
# Generate self-signed SSL certificates for local/dev HTTPS testing
# Usage: ./generate-certs.sh [domain]

DOMAIN="${1:-localhost}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Generating self-signed certificate for: ${DOMAIN}"

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "${SCRIPT_DIR}/privkey.pem" \
  -out "${SCRIPT_DIR}/fullchain.pem" \
  -subj "/C=CZ/ST=Prague/L=Prague/O=ASSLover/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN},IP:127.0.0.1"

echo "Certificates generated:"
echo "  ${SCRIPT_DIR}/fullchain.pem"
echo "  ${SCRIPT_DIR}/privkey.pem"
echo ""
echo "To use with docker-compose, uncomment the SSL section in docker-compose.prod.yaml"
