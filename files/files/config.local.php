<?php
// NOTE:
$CONF['database_type'] = 'mysqli';
$CONF['setup_password'] = '<replace-with-setup-password-hash>';
$CONF['database_host'] = '<replace-this-db-host>';
$CONF['database_user'] = 'admin';
$CONF['database_password'] = '<replace-this-db-password>';
$CONF['database_name'] = 'mail';
$CONF['encrypt'] = 'dovecot:CRAM-MD5';
$CONF['dovecotpw'] = "/usr/bin/doveadm pw";
$CONF['configured'] = true;
?>