FROM ubuntu:bionic

LABEL maintainer="Andrey Mikhalchuk <andrey@mikhalchuk.com>"

ENV DEBIAN_FRONTEND=noninteractive \
    VERSION_POSTFIXADMIN=3.2 \
    VERSION_DOVECOT=2.3

RUN apt-get update && \
    apt-get install -y \
        apt-utils \
        curl \
        lsb-release \
        rsyslog \
        spamassassin \
        spamc \
        uucp \
        mysql-server \
        procps \
        vim \
        telnet

RUN curl https://repo.dovecot.org/DOVECOT-REPO-GPG | apt-key add - && \
    echo "deb https://repo.dovecot.org/ce-${VERSION_DOVECOT}-latest/ubuntu/$(lsb_release -cs) $(lsb_release -cs) main" | tee -a /etc/apt/sources.list.d/dovecot.list

RUN apt-get update && \
    apt-get install -y \
        postfix \
        postfix-mysql \
        dovecot-mysql \
        dovecot-imapd \
        dovecot-pop3d \
        dovecot-lmtpd \
        spamassassin

# NOTE: /data/vmail  will be creted by adduser command
RUN mkdir -p /data/spamassassin/log /www /data/ssl && \
    addgroup --gid 500 vmail && \
    adduser vmail --uid 500 --gid 500 -q --home /data/vmail --disabled-password --gecos "" && \
    adduser spamd -q --disabled-login  --gecos ""

RUN curl -L https://downloads.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-${VERSION_POSTFIXADMIN}/postfixadmin-${VERSION_POSTFIXADMIN}.tar.gz | tar -C /tmp -xz && \
    mkdir -p /www/postfixadmin && \
    mv /tmp/postfixadmin-${VERSION_POSTFIXADMIN}/* /www/postfixadmin && \
    mkdir /www/postfixadmin/templates_c && \
    chown www-data:www-data /www/postfixadmin/templates_c

RUN apt-get install -y \
        nginx \
        libfreetype6-dev \
        libjpeg-turbo8-dev \
        libmcrypt-dev \
        libpng-dev \
        libjpeg-dev \
        php-dev \
        php-fpm \
        php-pear \
        php-mysqli \
        php-iconv \
        php-gd \
        php-common \
        php-mbstring \
        php-imap \
        libgl-dev \
        webp  && \
     mkdir -p /run/php && \
     chown www-data:www-data /run/php

RUN pecl channel-update pecl.php.net && \
    pecl install mcrypt-1.0.3 && \
    phpenmod mysqli && \
    phpenmod iconv && \
    phpenmod mcrypt

COPY files /

RUN chmod +x /start.sh

# ports used (do not expose them if you don't want them for security reasons:
# 25 - SMTP
# 80 - pfadmin
# 110 - pop3
# 143 - imap
# 465 - SMTP over SSL
# 587 - email submission port
# 993 - IMAP over SSL
# 995 - POP3 over SSL
VOLUME [ "/var/log/", "/var/vmail/", "/var/lib/mysql", "/data/ssl" ]
EXPOSE 25 80 110 143 465 993 995

CMD ["/start.sh"]