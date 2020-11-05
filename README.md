**Run a complete mail server in minutes!**

# Intro
This docker image implements a fully-functional mailserver including 
- postfix 3.3.0 - the SMTP server
- dovecot 2.3.9.2 - the IMAP and POP3 server
- postfixadmin 3.2 - the web interface for managing domains and mailboxes (users) for both the dovecot and postfix
- spamassassin - the anti-spam agent :) It evaluates incoming emails and marks the ones that do not pass the smell test as "*****SPAM*****"   
- opendkim - the DKIM support
- also see information below on how to configure DMARC and SPF

# How to run
* `MAIL_BASE_DIR=/docker_data/mail` - this is where you want to keep all files related to the mail system including 
the configuration, the mail, the database, and the logs  
* Here is an example command to run the whole contraption:

`docker run -d --name mail --restart=unless-stopped -v ${MAIL_BASE_DIR}/log:/var/log -v ${MAIL_BASE_DIR}/vmail:/var/vmail 
-v ${MAIL_BASE_DIR}/mysql:/var/lib/mysql -v ${MAIL_BASE_DIR}/mail/opendkim:/etc/opendkim 
-v ${MAIL_BASE_DIR}/ssl:/data/ssl 
-p 25:25 -p 465:465 -p 993:993 -p 10090:80 -p 587:587 -p 110:110 -p 143:143 -p 995:995  
--hostname=my.mailserver.com -e DB_PASSWORD=secret_password_1 -e DB_HOST=localhost -e SETUP_PASSWORD=secret_password_2 
craftus/mailserver`

Here is what it means:
* `docker run` - means "start the docker container from the image"
* `-d` - will run it in the background, so this command won't block your terminal
* `--restart=unless-stopped` - if you will restart Docker (or your server/computer) this will restart the container when 
the docker daemon will start again
* `--name mail` - gives a name to the docker container, makes it easier to manage it once it's running
* `-v ${MAIL_BASE_DIR}/log:/var/log` - this will persist mail log files in ${MAIL_BASE_DIR}/log. 
This and the rest of the `-v HOST_DIR:CONTAINER_DIR` configuration parameters map directories from your computer to the 
container's file system so that the files in these directories could persist between the container restarts. If you do 
not want to persist the logs and totally fine with the default configuration files then you can omit most of the `-v ...` 
options. 
* `-v ${MAIL_BASE_DIR}/vmail:/var/vmail` - the actual emails will be stored in this folder
* `-v ${MAIL_BASE_DIR}/mysql:/var/lib/mysql` - this is where MySQL will keep the data (mail server and postfixadmin configuration in our cafe) 
* `-v ${MAIL_BASE_DIR}/mail/opendkim:/etc/opendkim` - keep DKIM files here
* `-v ${MAIL_BASE_DIR}/ssl:/data/ssl` - keep your mail (not HTTP, see below) SSL certificates here. BTW, I wrote an article explaining how you can 
get the SSL certificates for free: https://andrey.mikhalchuk.com/2020/06/04/how-to-get-free-domain-aka-wildcard-certificates.html 
* `-p 25:25 -p 465:465 -p 993:993 -p 587:587 -p 110:110 -p 143:143 -p 995:995` - this will map all the ports 
required for the mail server operation to the host ports. Here is a brief explanation of the purpose of each port:
    * 80 - postfixadmin
    * 110 - pop3
    * 143 - imap
    * 465 - SMTP over SSL
    * 587 - email submission port
    * 993 - IMAP over SSL
    * 995 - POP3 over SSL
* `-p 10090:80` - postfixadmin will be mapped to this port on the host
* `--hostname=my.mailserver.com` - change "my.mailserver.com" to the actual name of your mailserver 
(the one mail clients will be connecting to)
* `-e DB_PASSWORD=secret_password_1` - change "secret_password_1" to some complex password. This is the password for the 
MySQL database used "admin" used by various parts of this system to store and read data in the database.
* `-e DB_HOST=localhost` - This image already includes mysql server, but if for some reason you want to use an external 
database you can replace "localhost" here with the hostname of your database.
* `-e SETUP_PASSWORD=secret_password_2` - replace "secret_password_2" with a password of your choice. You will need it
to set up postfixadmin
* `craftus/mailserver` - the name of this docker image

Unless you provided your own ${MAIL_BASE_DIR}/dh.param file (most likely you didn't and that's ok) and put it into the 
directory that is mapped to the container's /data/ssl directory, it will take quite some time for the container to 
start for the first time. It could be 5-30 minutes until it's fully operational. This time will be required to generate 
the dh.param file and until it's done dovecot will not be available. Just watch the container log to see when this 
process is completed, use this command: `docker logs -f mail`. All future container starts will be a lot faster since this
file only need to be generated once.

Now you can go to http://localhost:10090/setup.php in your browser, and configure postfixadmin using the passwords you specified 
in the `docker run` command listed above. If you will see errors on that page, then just reload it and the errors will be 
gone (this seems to be a postfixadmin bug). 
After initial setup you can go to http://localhost:10090/ (postfixadmin setup won't redirect you automatically) and specify the 
domains you want the mailserver to serve, create real or virtual mailboxes, specify quotas and more, all in the 
convenience of the postfixadmin web interface

# Is there anything else I need to do?
* One thing this container doesn't do is it doesn't include a web server. It does that for a simple reason that you may 
not want to run one at all or you may already have one running. I'd recommend putting a web server between the postfixadmin 
and the world so that you can protect it with some sort of authentication and add SSL/TLS on top. If you're looking for a 
good web server container, here is one: https://hub.docker.com/repository/docker/rtfms/nginx-php 
And here is an example of nginx configuration that could do the trick:
```
server {
    listen 80;
    # this bit is used by the certbot, a way to get a free SSL certificate,
    # you can find the details in my blog: https://andrey.mikhalchuk.com/2020/06/04/how-to-get-free-domain-aka-wildcard-certificates.html
    # and https://andrey.mikhalchuk.com/2020/05/14/stop-paying-for-ssl-certificates.html
    location /.well-known/ { 
      root /www/certbot;
    }
    # This will permanently redirect people who came to http version of the site to the https version.
    # Use 302 instead of 301 for the development purposes
    location / {
      return 301 https://$host$request_uri;
    }
    server_name my.mailserver.com; # the one specified in the "docker run" command
}

server {
      listen       443 ssl;

      # Change the paths to the ssl_* directories to wherever your certbot is keeping the certificates
      ssl_certificate /docker_data/mail/ssl/certbot/etc/live/my.mailserver.com/fullchain.pem;
      ssl_certificate_key /docker_data/mail/ssl/certbot/etc/live/my.mailserver.com/privkey.pem;
      ssl_prefer_server_ciphers On;
      ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
      ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;

      server_name my.mailserver.com; # the one specified in the "docker run" command
      location / {
        proxy_pass http://localhost:10090; # proxy to the port mapped for the postfixadmin
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
      }
      # turns on Basic HTTP Authentication, see below
      auth_basic "htpasswd";
      auth_basic_user_file  /docker_data/mail/htpasswd; 
}
```
* In this config file you can see `auth_basic "htpasswd"; auth_basic_user_file  /docker_data/mail/htpasswd;` lines. 
These will turn on basic HTTP authentication for the postfixadmin web interface. You can create the users with the 
`htpasswd -c <filename> <username>` command from the host.
* Finally, I'd recommend adding the SSL certificates to this configuration using Let's Encrypt and Certbot (it's free!). 
You can find the links to my posts about how to do it above. BTW, you can use the same certificates for the mail 
server and for the HTTP server by pointing nginx to the files you put into ${MAIL_BASE_DIR}/ssl. Here are the names of
the certificate files used by the mail services (all paths are relative to the container):
  * /data/ssl/mail.crt
  * /data/ssl/mail.key
  * /data/ssl/dh.param
* If you will decide to change SETUP_PASSWORD then /setup.php page will instruct you to change config.local.php and put 
a specific value into the $CONF['setup_password'] variable. You can do this by starting shell in the container as 
"docker exec -it mail bash" and then using vi to edit /www/postfixadmin/config.local.php. It would be also wise to rename, 
move or change permissions /www/postfixadmin/public/setup.php to make it inaccessible after the initial setup.
* Note that mysql running within this docker container is unsecured. Refer to these instructions for securing it: 
https://dev.mysql.com/doc/refman/8.0/en/resetting-permissions.html
* If you're running this mailserver in the production environment, then you may want to register it on https://postmaster.google.com/

# How to configure DKIM and DMARC
By default, if you do nothing, the mailserver will work, but DKIM won't. The container will generate some stub files so 
that opendkim could start, postfix will still use it, but emails will be leaving the server unsigned. In order to add 
DKIM for specific domains you need to do the following:
* run a shell in the container: "docker exec -it mail bash"
* in the shell go to /etc/opendkim: "cd /etc/opendkim"
* you will need to do the following steps for each domain. Let's say we're addim DKIM for example.com:
* edit file called TrustedHosts. Keep the first 3 lines intact and append new line: `*.example.com`
* edit file called KeyTable. Append a line looking like this: `mail._domainkey.example.com example.com:mail:/etc/opendkim/keys/example.com/mail.private`
* edit file called SigningTable. Append a line looking like this: `*@example.com mail._domainkey.example.com`
* run the following commands: `mkdir example.com && cd example.com && opendkim-genkey -s mail -d example.com && chown opendkim:opendkim mail.private && cat mail.txt && cd ..`
* this will create the signing keys and print out the DNS record that will look like this:
```
	  mail._domainkey	IN	TXT	( "v=DKIM1; h=sha256; k=rsa; "
	  "p=very_long_line"
	  "another_very_long_line" )  ; ----- DKIM key mail for example.com
```
* now update your DNS record. If you're hosting your own DNS then you need to update your "named" files or their equivalent. 
If you're using a registrar providing a nice-looking web interface for editing DNS (not you, GoDaddy!), then create a new 
TXT entry named `mail._domainkey`
with the following content: `v=DKIM1; h=sha256; k=rsa; p=very_long_lineanother_very_long_line`, i.e. concatenate the lines,
get rid of double quotes, keep everything else intact. 
* Now, once DKIM is configured, you can set up DMARC for the same domain. Add a TXT DNS record named `_dmarc.example.com` looking like this `v=DMARC1; p=none; rua=mailto:dmarc@example.com`. This is the most
basic form, you can learn about other configuration parameters here: https://support.google.com/a/answer/2466563?hl=en&ref_topic=2759254

# How to test this mail server?
I'm, using Mozilla Thunderbird for this, but you can use any mail client and configure it as following:
* Name of the account: Name it as you wish
* Login: full email address including the domain (obviously, you will need to create this account in postfixadmin first)
* Incoming IMAP, 993, SSL/TLS Normal password
* Outgoing SMTP, 465 SSL/TLS Normal password
* NOTE: Thunderbird is not working well if you're using self-signed certificates, find more here: 
https://serverfault.com/questions/532172/thunderbird-not-trusting-certificate-signed-with-self-signed-authority. Other mail
clients are working fine, but the best approach is to use SSL from a trusted provider (see the links above)

# How to build it locally
* Checkout the git repository: git clone https://github.com/craftus/mailserver.git
* Modify the Dockerfile if necessary
* Build the image: `docker build -t mailserver .`
* When you will need to run the new docker image, use `mailserver` instead of `craftus/mailserver`

# Can I use this image in production?
You can, with the proper security measures (like configuring the filrewall, LIDS, antivirus etc) and after providing 
appropriate configuration files.

Another thing worth noting is that this image is against the Docker paradigm which includes the idea of running primitive 
services in their own docker containers. This container includes a lot of services sharing a lot of common configuration 
files, folders and database tables, which, in ideal world, should be split into separate images and started together 
using docker-compose or a similar tool. This approach is not very convenient though, because:
- hub.docker.com does not support docker-compose.yml files (at least at the moment)
- docker-compose is an executable separate from docker and may or may not be installed on the target system
- fewer containers are easier to manage, just IMHO
- making all these containers friends will require a lot of work and will make the whole thing a lot more fragile 

I hope that this image could be a good foundation for the production config after you edit the Docker file, and the
config files to meet your specific configuration and security needs and then remove all unnecessary components and tools
from it by updating the Dockerfile.

