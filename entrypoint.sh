#!/bin/sh

set -e

POSTFIX_CERT_DIR="/etc/postfix/cert"

# If there are no on of necessary certs/keys - let's generate them all again
if ! [ -s "$POSTFIX_CERT_DIR/${POSTFIX_EMAIL_HOST}.key" -a -s "$POSTFIX_CERT_DIR/${POSTFIX_EMAIL_HOST}.crt" -a -s "$POSTFIX_CERT_DIR/rootCA.pem" ]; then
    echo "Generate mail certs for Postfix Mail Domain is ${POSTFIX_EMAIL_HOST}"
    if ! gencert.sh ${POSTFIX_EMAIL_HOST} ${POSTFIX_ADDITIONAL_DOMAINS}; then
        echo "gencert.sh failed to generate certificates/keys due to some error."
    fi
fi

# Finally, if all certs/keys are peresent on FS, configure Postfix for using SSL/TLS
if [ -s "$POSTFIX_CERT_DIR/${POSTFIX_EMAIL_HOST}.key" -a -s "$POSTFIX_CERT_DIR/${POSTFIX_EMAIL_HOST}.crt" -a -s "$POSTFIX_CERT_DIR/rootCA.pem" ]; then
    echo "All cert/keys are at the place, configure Postfix for SSL/TLS"
    postconf -e "smtp_tls_security_level = may"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtpd_tls_auth_only = no"
    postconf -e "smtpd_tls_key_file = ${POSTFIX_CERT_DIR}/${POSTFIX_EMAIL_HOST}.key"
    postconf -e "smtpd_tls_cert_file = ${POSTFIX_CERT_DIR}/${POSTFIX_EMAIL_HOST}.crt"
    postconf -e "smtpd_tls_CAfile = ${POSTFIX_CERT_DIR}/rootCA.pem"
    postconf -e "tls_random_source = dev:/dev/urandom"
    # Use '2' for debugging SSL/TLS
    postconf -e "smtp_tls_loglevel = 0"
    echo "Postfix is now configured to use SSL/TLS for sending/receiving mail."
fi

if [ -n "${POSTFIX_ADDITIONAL_DOMAINS}" ]; then
    postconf -e "smtputf8_enable = no"
fi

# Disable smtputf8, because libraries (ICU) are missing
postconf -e "smtputf8_enable = no"

# Update aliases database. It's not used, but postfix complains if the .db file is missing
postalias /etc/postfix/aliases

# Set hostname
postconf -e "myhostname = ${POSTFIX_EMAIL_HOST}"
# Disable local mail delivery
postconf -e "mydestination ="
# Don't relay for any domains
postconf -e "relay_domains ="

# Reject invalid HELOs
postconf -e "smtpd_delay_reject = yes"
postconf -e "smtpd_helo_required = yes"
postconf -e "smtpd_helo_restrictions = permit_mynetworks,reject_invalid_helo_hostname,permit"

# Allow to send emails only from containers in same docker network
docker_network=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{split($01,addr,"."); print addr[1]"."addr[2]".0.0/16"}')
postconf -e "mynetworks = $docker_network"

# Don't restrict sender
postconf -# "smtpd_restriction_classes"
postconf -e "smtpd_recipient_restrictions = reject_non_fqdn_recipient,reject_unknown_recipient_domain,reject_unverified_recipient"

# Use 587 (submission)
sed -i -r -e 's/^#submission/submission/' /etc/postfix/master.cf

# Set correct permissions
mkdir -p /var/spool/postfix
chown root /var/spool/postfix
chown root /var/spool/postfix/pid

exec $@
