FROM alpine:edge
LABEL Vadim Bazhov <b.vadim@jetstyle.ru>

RUN	apk add --no-cache postfix ca-certificates supervisor rsyslog openssl opendkim opendkim-utils \
    && install -d /etc/supervisor.d

COPY assets/rsyslog.conf /etc/rsyslog.conf

COPY assets/supervisord/supervisord.conf /etc/supervisord.conf
COPY assets/supervisord/postfix.conf assets/supervisord/rsyslog.conf /etc/supervisor.d/

COPY assets/opendkim/opendkim.conf /etc/opendkim/
COPY assets/entrypoint.sh assets/gen_postfix_certs.sh assets/opendkim/opendkim_setup.sh /usr/local/bin/

RUN	chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/gen_postfix_certs.sh /usr/local/bin/opendkim_setup.sh

USER root
WORKDIR	/tmp

EXPOSE 587
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
