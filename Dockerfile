FROM alpine:latest
LABEL Vadim Bazhov <b.vadim@jetstyle.ru>

RUN	apk add --no-cache postfix ca-certificates supervisor rsyslog openssl

COPY rsyslog.conf /etc/rsyslog.conf
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /usr/local/bin
COPY gencert.sh /usr/local/bin/
RUN	chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/gencert.sh

USER root
WORKDIR	/tmp

EXPOSE 587
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
