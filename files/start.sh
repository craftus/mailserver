#!/bin/sh

PSSW=`doveadm pw -s CRAM-MD5 -p $SETUP_PASSWORD | sed 's/{CRAM-MD5}//'`

# this will apply the environment variable during the first start
# even though this command will keep running over and over again
# the env vars won't be applied.
HASHED_SETUP_PASSWORD=`php /files/generate-setup-password.php "${SETUP_PASSWORD}"`
SERVER_NAME=`hostname`
sed -i " s/<replace-with-setup-password-hash>/${HASHED_SETUP_PASSWORD}/;  s/<replace-this-server-name>/${SERVER_NAME}/; s/<replace-this-password>/${SETUP_PASSWORD}/; s/<replace-this-db-password>/${DB_PASSWORD}/; s/<replace-this-db-host>/${DB_HOST}/" \
  /etc/postfix/main.cf \
  /etc/dovecot/dovecot-sql.conf.ext \
  /etc/postfix/main.cf \
  /etc/postfix/mysql-*.cf \
  /etc/nginx/nginx.conf \
  /files/config.local.php \
  /files/initialize-database.sql

if [ ! -f "/www/postfixadmin/config.local.php" ]; then
  echo "It doesn't seem like the postfixadmin is configured, so copying the config file now"
  cp /files/config.local.php /www/postfixadmin
fi

if [ ! -d "/var/log/nginx" ]; then
  mkdir -p /var/log/nginx
  chown www-data:www-data /var/log/nginx
fi

if [ ! -d "/var/log/php-fpm" ]; then
  mkdir -p /var/log/php-fpm
  chown www-data:www-data /var/log/php-fpm
fi

if [ ! -d "/var/run/mysqld" ]; then
  mkdir -p /var/run/mysqld
  chown mysql:mysql /var/run/mysqld
fi

mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql
if [ ! -d "/var/lib/mysql/mysql" ]; then #  -o ! -f "/var/lib/mysql/"
  echo "Mysql doesn't seem to be initialized. Initializing."
  mkdir -p /var/run/mysqld /var/log/mysql /var/lib/mysql
  chown -R mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql
  mysqld --initialize-insecure
fi
mysqld_safe&
sleep 5

if [ ! -d "/var/lib/mysql/mail" ]; then
  echo "Mail database doesn't seem to exist, creating its user"
  mysql -e "CREATE DATABASE mail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;GRANT ALL PRIVILEGES ON mail.* TO admin@localhost IDENTIFIED BY '${DB_PASSWORD}';FLUSH PRIVILEGES;"
fi

if [ ! -f "/data/ssl/mail.crt" -o ! -f "/data/ssl/mail.key" ]; then
  echo "You didn't provide your own SSL certificates, so generating self-signed valid for 10 years."
  echo "This is not secure and you should provide the reasl certificates for your server"
  openssl req -new -x509 -nodes -config /usr/share/dovecot/dovecot-openssl.cnf -out /data/ssl/mail.crt -keyout /data/ssl/mail.key -days 3650  -subj "/CN=${SERVER_NAME}" -extensions v3_ca || exit 2
  openssl x509 -subject -fingerprint -noout -in /data/ssl/mail.crt || exit 2
  chmod 0440 /data/ssl/mail.key
  chmod 0444 /data/ssl/mail.crt
  chown root:vmail /data/ssl/*
fi

if [ ! -f "/etc/opendkim/TrustedHosts" ]; then
  mkdir -p /etc/opendkim
  cat << EOT >  /etc/opendkim/TrustedHosts
127.0.0.1
localhost
192.168.0.1/24
EOT
fi

if [ ! -f "/etc/opendkim/SigningTable" ]; then
  mkdir -p /etc/opendkim
  touch /etc/opendkim/SigningTable
fi

if [ ! -f "/etc/opendkim/KeyTable" ]; then
  mkdir -p /etc/opendkim
  touch /etc/opendkim/KeyTable
fi


php-fpm7.2
nginx
/etc/init.d/postfix start
/etc/init.d/rsyslog start
/etc/init.d/spamassassin start
if [ ! -f "/data/ssl/private/dh.param" ]; then
  echo "You didn't provide your own Diffie Hellman parameters, which is ok."
  echo "Generating the new parameters, this may take a long time but will only take place on the first image start (if you correctly mounted /data/ssl)"
  mkdir -p /data/ssl/private
  openssl dhparam 4096 > /data/ssl/private/dh.param
  chown 0440 /data/ssl/private/dh.param
fi
/usr/sbin/opendkim
/usr/sbin/dovecot -F
