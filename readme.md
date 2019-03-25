## Postfix docker container
Автоматически настраивает SSL/TLS с генерируя самоподписанный сертификат при запуске.
Есть возможность использовать свои сертификаты.

## Конфигурирование

Переменные окружения используемые контейнером:

**POSTFIX_EMAIL_HOST** (required): Основной почтовый домен для postfix.
Используется в качестве CN для самоподписанного сертификата.
**POSTFIX_ADDITIONAL_DOMAINS**: дополнительные почтовые домены для postfix.
Используются в качестве Alt Names для самоподписанного сертификата.

Контейнер при запуске проверяет наличие сертифкатов/ключей в /etc/postfix/cert.
Если не находит их - генерирует самоподписанные сертификаты и приватные ключи и кладет их в этот каталог.
Если каталог уже содержит необходимые файлы, то генерация новых не происходит.
Posfix настраивается на использование SSL/TLS с этими сертификатами.
Файлы, наличие которых проверяется в `/etc/postfix/cert`:

- rootCA.key: server privete key
- rootCA.pem: server public certificate
- {POSTFIX_EMAIL_HOST}.crt: Main mail domain certificate
- {POSTFIX_EMAIL_HOST}.key: Main mail domain private key

Таким образом к каталогу `/etc/postfix/cert` контейнера можно подключить volume содержащий, например,
купленный сертификат на домен или полученный с помощью letsencrypt и он будет использоваться для postfix.
В таком случае самоподписанный сертификат при запуске контейнера создан не будет.
Имена файлов должны быть именно такие как указаны выше.
Base name файлов сертификата и ключа домена **обязательно должны совпадать** с переменной `POSTFIX_EMAIL_HOST`.

Пример: если вы используете этот контейнер и у вас есть ключ и сертификат для домена `mydomain.me`, то в монтируемом volume
должны находиться следущие файлы:

    rootCA.key
    rootCA.pem
    mydomain.me.crt
    mydomain.me.key

Если меняете `$POSTFIX_CERT_DIR` в entrypoint то поменяйте его и в `gencert.sh`.

## TODO:
- Настроить OpenDKIM так же с генерацией самоподписанных сертификатов для доменов и мочь подключать volume с кастомными
- Начиная с Postfix 3.4 попробовать избавиться от supervisord и syslog. Для логирования в stdout использовать postlogd:
    http://www.postfix.org/MAILLOG_README.html