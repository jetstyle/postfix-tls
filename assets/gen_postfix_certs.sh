#!/bin/sh

set -e

# Originally taken here by Vadim Bazhov at Jetstyle (b.vadim@jetstyle.ru):
# https://support.plesk.com/hc/en-us/article_attachments/360005259853/cert.sh

SCRIPT_NAME=${0##*/}
CN=$1
CERT_DIR="/etc/postfix/cert"
SAN="DNS:mail.${CN}"
OPENSSL_CONF="/tmp/openssl.cnf"

country=RU
state=Sverdlovsk
locality=Yekaterinburg
organization=Jetstyle
organizationalunit='Dev Team'
email=info@jetstyle.ru

function log() {
    echo "$SCRIPT_NAME: $1"
}

if [ -z "$CN" ]; then
    log "Argument not present."
    log "Usage ${SCRIPT_NAME} [domain name for CN name]"
    exit 99
fi

log "Construct Subject Alt Names from additional positional arguments"
shift
for arg in "$@"
do
    log "Found additional domain: ${arg}"
    SAN="${SAN},DNS:$arg"
done

echo "
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
x509_extensions    = v3_req

[req_distinguished_name]
commonName       = ${CN}
emailAddress     = ${email}
organizationName = ${organization}
localityName     = ${locality}
countryName      = ${country}

[v3_req]
subjectKeyIdentifier = hash
basicConstraints     = critical,CA:false
subjectAltName       = ${SAN}
keyUsage             = critical,digitalSignature,keyEncipherment
" > ${OPENSSL_CONF}

log "Changing working directory to /tmp"
cd /tmp

log "Generating a root private key and creating a self-signed CA"
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -days 3650 -out rootCA.pem -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$CN/emailAddress=$email" -config ${OPENSSL_CONF}

log "Generating key request for CN"

log "Generate a private key for the certificate"
openssl genrsa -out ${CN}.key 4096
chmod 400  ${CN}.key

log "Create the request"
openssl req -new -key ${CN}.key -out ${CN}.csr -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$CN/emailAddress=$email" -config ${OPENSSL_CONF}

log "Create endpoint certificate"
openssl x509 -req -in ${CN}.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out ${CN}.crt -days 3650 -extfile ${OPENSSL_CONF}  -extensions v3_req

log "Placing keys and certificates to the right places on filesystem"
install -d ${CERT_DIR}
mv rootCA.key ${CERT_DIR}
mv rootCA.pem ${CERT_DIR}
mv "${CN}.key" ${CERT_DIR}
mv "${CN}.crt" ${CERT_DIR}

log "Removing unnecessary files"
rm -f rootCA.srl
rm -f "${CN}.csr"
rm -f ${OPENSSL_CONF}

log "Certificates and keys for $CN are made and installed to $CERT_DIR."
