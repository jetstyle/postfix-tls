#!/bin/sh

set -e

if [ -z "$DKIM_DOMAINS" ]; then
    echo 'No domains passed. Disable Opendkim service and exit.'
    rm -f "/etc/supervisor.d/opendkim.conf"
    exit 0
fi

# Sort, uniquify and lowercase the list of mail domains
DKIM_DOMAINS=$(echo ${DKIM_DOMAINS} | tr '[:upper:]' '[:lower:]' | tr " " "\n" | sort | uniq | tr "\n" " ")

echo "DKIM domains: $DKIM_DOMAINS"

[ -z "$DKIM_SELECTOR" ] && DKIM_SELECTOR="mail"

[ -z "$DKIM_KEY_LEN" ] && DKIM_KEY_LEN=2048

[ -z $DOCKER_NETWORK ] && DOCKER_NETWORK=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{split($01,addr,"."); print addr[1]"."addr[2]".0.0/16"}')

echo "
[program:opendkim]
command=/usr/sbin/opendkim -x /etc/opendkim/opendkim.conf -f
" > /etc/supervisor.d/opendkim.conf

echo "
127.0.0.1
localhost
$DOCKER_NETWORK
" > /etc/opendkim/TrustedHosts

install -d "/etc/opendkim/keys/"

for domain in $(echo ${DKIM_DOMAINS} | tr '[:upper:]' '[:lower:]' | tr " " "\n" | sort | uniq); do
    keydir="/etc/opendkim/keys/${domain}"
    if ! [ -s "${keydir}/${DKIM_SELECTOR}.private" -a -s "${keydir}/${DKIM_SELECTOR}.txt" ]; then
        install -d ${keydir}
        echo "Generating new key for domain: ${domain}"
        opendkim-genkey -b ${DKIM_KEY_LEN} -d ${domain}. -D ${keydir} -r -s ${DKIM_SELECTOR} --nosubdomains -v

        echo "${DKIM_SELECTOR}._domainkey.${domain} ${domain}:${DKIM_SELECTOR}:${keydir}/${DKIM_SELECTOR}.private" >> /etc/opendkim/KeyTable
        echo "${domain} ${DKIM_SELECTOR}._domainkey.${domain}" >> /etc/opendkim/SigningTable
        chmod 400 "${keydir}/${DKIM_SELECTOR}.private"
    fi
    echo -e "\nYou must set DNS domainkey record for domain ${domain} exactly as shown in next lines except comment started with '-----':\n"
    cat "${keydir}/${DKIM_SELECTOR}.txt"
done

chown -R opendkim:opendkim "/etc/opendkim/keys/"

# Need this directory for pid and socket files
install -d /var/run/opendkim/
chown opendkim:mail /var/run/opendkim/

# Set up postfix to use opendkim as milter
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=unix:/var/run/opendkim/opendkim.sock
postconf -e non_smtpd_milters=unix:/var/run/opendkim/opendkim.sock
