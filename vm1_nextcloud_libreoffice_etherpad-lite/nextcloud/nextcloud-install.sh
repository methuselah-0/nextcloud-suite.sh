#!/bin/bash

# Copyright © 2017 David Larsson <david.larsson@selfhosted.xyz>
#
# This file is part of Nextcloud-Suite.sh.
# 
# Nextcloud-Suite.sh is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# Nextcloud-Suite.sh is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Nextcloud-Suite.sh.  If not, see
# <http://www.gnu.org/licenses/>.

#  For sysinfo: https://bash.cyberciti.biz/guide/Getting_information_about_your_system

sdomain="cloud"
mydomain="domain.tld"
nc="/var/www/$mydomain/nextcloud"
ncurl="https://download.nextcloud.com/server/releases/nextcloud-11.0.2.zip"
ncfile="nextcloud-11.0.2.zip"
htuser="www-data"
htgroup="www-data"
rootuser="root"
dbtype="mysql"
dbname="nextcloud"
dbpass="password"
dbrootpass="something"
dbrootuser="root"
ncadmin="admin"
ncadminpass="password"
 
# spreed variables at install section.
#spreed=/opt/spreed
#spreedusr="spreed"

### Step 1
#
# Download and install nextcloud
#cd $nc && wget $ncurl
unzip $ncfile && ls

### Alternative all-in-one for new installs If-fresh machine statement then use this:
#
# reference https://docs.nextcloud.com/server/10/admin_manual/installation/command_line_installation.html
# detailed ref: https://docs.nextcloud.com/server/10/admin_manual/configuration_server/occ_command.html#command-line-installation-label
chown -R $htuser:$htgroup $nc

#
# Automatic install method only for fresh boxes.
#cd $nc && sudo -u $htuser php occ  maintenance:install --database
#$dbtype --database-name $dbname  --database-user $dbuser --database-pass
#$dbpass --admin-user $adminuser --admin-pass $adminpass

### Step 2
#
# create new database - how to pass commands directly? mb4 for emojis
#mysql --user=root --password=$dbrootpass
#CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci; don't use "create user <username>@localhost identified by '<password>'"
#grant all privileges on nextcloud.* to <username>@localhost identified by 'your-password';
#flush privileges;
#exit;

### Step 3
#
# Configure PHP7
# /etc/php/7.0/fpm/pool.d/www.conf uncomment these:
: <<'END'
;env[HOSTNAME] = $HOSTNAME
;env[PATH] = /usr/local/bin:/usr/bin:/bin
;env[TMP] = /tmp
;env[TMPDIR] = /tmp
;env[TEMP] = /tmp
END
# also change default pm.max_children = 5 to pm.max_children = 40 

# /etc/php/7.0/php.ini
#Sed or cat this. If you wanna change default maximum file upload size etc you can set it to maximum size 5 gigabyte. 
#upload_max_filesize = 5G
#post_max_size = 5G

# APCu and Redis- server for memcaching
# apt-get install redis-server php7.0-redis php7.0-apcu

### Step 4
#
# Nextcloud post-install.

# Step 4.1
#
# Trusted domains and caching configuration.
# Sed this. All hosts requiring access for this instance: config/config.php or just config.php
# 'trusted_domains' =>
# array (
#    0 => 'localhost',
#    1 => 'server1.example.com',
#    2 => '192.168.1.50',
#    ),
# Also enable local and redis memcaching
# 'memcache.local' => '\OC\Memcache\APCu',
# 'filelocking.enabled' => true,
#'memcache.locking' => '\OC\Memcache\Redis',
# This redis server runs on IP loopback instead of socket by default.
#'redis' =>
#array(
#    'host' => 'localhost',
#    'port' => 6379,
#),
#'maintenance' => false,
#);
# However, it is recommended to run on socket instead when Nextcloud is on the same host as redis server. Ref: https://docs.nextcloud.com/server/11/admin_manual/configuration_files/files_locking_transactional.html
#  'redis' => array(
#    'host' => '/var/run/redis/redis.sock',
#    'port' => 0,
#    'timeout' => 0.0,
#  ),

# Step 4.2
#
# File permissions. ref: https://docs.nextcloud.com/server/10/admin_manual/installation/installation_wizard.html#strong-perms-label
printf "Creating possible missing Directories\n"
mkdir -p $nc/data
mkdir -p $nc/updater

printf "chmod Files and Directories\n"
find ${nc}/ -type f -print0 | xargs -0 chmod 0640
find ${nc}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${nc}/
chown -R ${htuser}:${htgroup} ${nc}/apps/
chown -R ${htuser}:${htgroup} ${nc}/config/
chown -R ${htuser}:${htgroup} ${nc}/data/
chown -R ${htuser}:${htgroup} ${nc}/themes/
chown -R ${htuser}:${htgroup} ${nc}/updater/

chmod +x ${nc}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${nc}/.htaccess ]
then
    chmod 0644 ${nc}/.htaccess
    chown ${rootuser}:${htgroup} ${nc}/.htaccess
fi
if [ -f ${nc}/data/.htaccess ]
then
    chmod 0644 ${nc}/data/.htaccess
    chown ${rootuser}:${htgroup} ${nc}/data/.htaccess
fi


### Step 5
#
# Ask to Install Common Apps
#
# Introduce official apps first, then 3rd party ones with mention of stability risk.


# Step 5.1
#
# Calendar
# just enable with occ cmd. Then echo that you need to press share in the interface to get the url from which you can import from let's say thunderbird.
# needs download and chown first and occ invoked with full path of app.
#sudo -u www-data php /var/www/$mydomain/nextcloud/occ -vvvv app:enable $ncc/apps/calendar 


# Step 5.3 LibreofficeOnline, see other script.

: <<EOF
# Step 5.4
#
# SpreedMe
#
# server consists of: spreedme-nextcloud app and spreed-webrtc server. Also STUN/TURN server for production env.
# STUN/TURN-ref(not using): https://github.com/coturn/coturn/wiki/turnadmin
#
# Section ref: https://github.com/strukturag/nextcloud-spreedme#installation--setup-of-a-spreed-webrtc-server
#
# The app
EOF
#spreednc="$nc/apps/spreedme"
#spreedncurl="https://github.com/strukturag/nextcloud-spreedme"
#spreednccommit="f17a97db5ee96792d5350286db53459b00b07d14"
# The server
#spreed="/opt/spreed"
#spreedurl="https://github.com/strukturag/spreed-webrtc"
#spreedcommit="e483679f0533bbcab063c7721df28c96fe8b86ce" # Oct 13, 2016
# Spreed-Me app install
#cd $nc/apps && git clone $spreedncurl
#mv $nc/apps/nextcloud-spreedme $spreednc
#cd $spreednc && git reset --hard $spreednccommit
# need config file with this path to configure without using nextcloud web interface.
#cd $spreednc/config/config.php.in $spreednc/config/config.php
#chown -R $htuser:$htgroup spreedme

### Spreed
# Build spreed-webrtc server from source
# install dependencies
#apt-get install automake autoconf golang node nodejs compass sass prefixer pybabel scsslint find gpm jshint
#cd $root && git clone https://github.com/strukturag/spreed-webrtc
#mv spreed-webrtc $spreed
#cd $spreed && git reset --hard $spreedcommit
#cd $spreed && ./autogen.sh
#cd $spreed && make
#chown www-data:www-data -R $spreed

### Spreed
#
# Post-install configuration

# Configuration 1 - $spreednc/config//config.php
#
# 1. Leave "const SPREED_WEBRTC_ORIGIN = '';"
# 2. generate "const OWNCLOUD_TEMPORARY_PASSWORD_SIGNING_KEY = 'key';" with key=`xxd -ps -l 32 -c 32 /dev/random`

# Configuration 2 - nginx
#
# for nginx configuration see this ref (and my own working config): https://github.com/strukturag/nextcloud-spreedme/blob/master/doc/example-config-nginx.md#how-to-run-spreed-webrtc-with-nginx-in-subpath
# and see nginx.conf 

# Configuration 3 - $spreed/server.conf
#
# 1. Go to admin page additional settings and press both generate signing key and generate shared secret and finally generate configuration.
# 2. Copy and save in e.g. libreoffice writer.
# 3. Spreed reads server.conf from its rootdir=$spreed/server.conf, so the generated configuration needs to be placed in /opt/spreed/server.conf#

# 
# server.conf needs to be aligned with sharedsecret_secret in $spreedme/config.php
#
# Copy shared secret info from server.conf to $spreedme/config.php
# It's the following line in $spreedme/config.php that needs replaced with sharedsecret_secret from server.conf:
# const SPREED_WEBRTC_SHAREDSECRET = 'bb04fb058e2d7fd19c5bdaa129e7883195f73a9c49414a7eXXXXXXXXXXXXXXXX';
#
# Allowing temporary password logins requires a signing key to be set for "const OWNCLOUD_TEMPORARY_PASSWORD_SIGNING_KEY" in $spreedme/config.php
#sigkey=`xxd -ps -l 32 -c 32 /dev/random`
# After these changes you need to restart spreed-webrtc-server.
# you can start the server with sudo -u www-data ./spreed-webrtc-server -l /opt/spreed/spreed.log and access it with nextcloud app.
#
# 
#cd $spreedme/extra/static/config
#cp OwnCloudConfig.js.in OwnCloudConfig.js

# Configuration 4 - configure mozilla browser
#
# reference: https://mozilla.github.io/webrtc-landing/
#media.getusermedia.screensharing.allowed_domains; append mydomain.com and cloud subdomain.
#media.getusermedia.audiocapture.enabled;true
#media.getusermedia.agc_enabled;true
#media.peerconnection.enabled;true
# Verify settings for
#media.peerconnection.turn.disable;false
#media.peerconnection.simulcast;true

# Spreed systemd unit run by separate user.
#
# adduser --system --ingroup $htgroup --home $spreed --no-create-home --disabled-login spreed 2>/dev/null || true
# touch /var/log/spreed.log && chown $spreedusr:htgroup /var/log/spreed.log

#
# Make whole spreed dir accessible to the user by chmodding, not chowning.
# chmod -R 755 /opt/spreed-webrtc-master

#cat EOT
#/etc/default/spreed
## Defaults for spreed-webrtc initscripts
#WEBRTC_USER='spreed'
#WEBRTC_GROUP='www-data'
#WEBRTC_CONF='/opt/spreed-webrtc-master/server.conf'
#WEBRTC_LOG='/var/log/spreed.log'
#WEBRTC_GOMAXPROCS=1
#WEBRTC_NOFILE=1024
#EOT

# For whatever reason (probably not on Debian, only Ubuntu) we need to define the server root directory in its configuration file, otherwise the service will fail:
# in /opt/spreed-webrtc-server/server.conf
# root = /opt/spreed-webrtc-master

#Finally we will create the systemd unit itself and enable it to establish the service:
: <<EOF
cat EOT
[Unit]
Description=Spreed WebRTC server
After=network.target
ConditionFileIsExecutable=/opt/spreed/spreed-webrtc-server
ConditionPathIsReadWrite=/etc/default/spreed
ConditionPathIsReadWrite=/var/www/mydomain.tld/nextcloud/apps/spreedme/extra

[Service]
Type=simple
UMask=022
EnvironmentFile=-/etc/default/spreed
# TODO: These values should come from the EnvironmentFile.
Environment=GOMAXPROCS=1
LimitNOFILE=1024
User=spreed
Group=www-data
PermissionsStartOnly=true
WorkingDirectory=/opt/spreed
#ExecStart=spreed-webrtc-server -c ${WEBRTC_CONF} -l ${WEBRTC_LOG}
ExecStart=/opt/spreed/bin/spreed-webrtc-server -c /opt/spreed/server.conf -l /var/log/spreed.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT
EOF

#systemctl enable spreed.service
#service spreed start

# Logrotation in /etc/logrotate.d/spreed
: <<EOF
cat EOT 

/var/log/spreed.log {
    rotate 5
    daily
    copytruncate
    notifempty
    missingok
}
EOT
EOF

#echo "Spreed logs are nog in /var/log/spreed.log and some info in /var/log/syslog."

#
# Step 5.5
#
# TURN server for SpreedME and Video-calls apps.
#
# Section ref1: https://github.com/coturn/coturn
# Section ref2: Ecphrasis comments
# https://help.nextcloud.com/t/complete-nc-installation-on-debian-with-spreed-me-and-turn-step-by-step/2436/38

#
# Install software
#
#apt-get install coturn

#
# Configure 1.
#
#/etc/turnserver.conf
:<<EOF
cat <<EOT > /etc/turnserver.conf 

listening-port=8443
alt-listening-port=3478
fingerprint
lt-cred-mech
use-auth-secret
# static-auth-secret same as turnSecret in Spreed WebRtc in /opt/spreed/server.conf
static-auth-secret='$authpass'
realm=$clouddomain 
total-quota=100
bps-capacity=0
stale-nonce
cipher-list="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5"
log-file=/var/log/turn.log
no-loopback-peers
no-multicast-peers
cert=/etc/letsencrypt/live/'$mydomain'/cert.pem
pkey=/etc/letsencrypt/live/'$mydomain'/privkey.pem
log-file=/var/log/turn.log

EOT
EOF

# Someone used "MyDnsService" instead of $clouddomain before, see ref2.
# use if quotes in cat eot don't work.
#sed authpass
#sed mydomain

#
# Configure 2 - /etc/default/coturn
#
# Run /etc/turnserver.conf as a service by uncommenting TURNSERVER_ENABLED=1
sed 's/TURNSERVER_ENABLED=0/TURNSERVER_ENABLED=1/g' /etc/default/coturn
# logfile
#sed /etc/turnserver.conf
#chown $htuser:$htgroup /var/log/turn.log
#turnadmin -A -u admin -p turn12for32spreed!

#
# Configure 3 - /etc/spreed/server.conf
#
# Set turnURIS in /etc/spreed/ and also "root=/usr/share/spreed-webrtc-server/www" or similar if using Ubuntu, see ref.
# (generated by openssl rand -hex 32)
# cat eot the four lines below.
#;# Using TURN instead of STUN
#;# secret manually generated by openssl rand -hex 32 and is same as /etc/turnserver.conf
#turnSecret=8f3a78fade3a3dc0dcf58074708e3e89f8a92bcdd6e1214f0c795402c0553c43
#turnURIs = turn:$sdomain.$mydomain:8443?transport=udp turn:$sdomain.$mydomain:8443?transport=tcp


# create turn-admin
#sudo turnadmin -A -u $turnadmin -p $turnadminpass
#echo "The admin panel of coturn is available by browser at the adress : https://mynextcloud:8443 wich allows me to see the sessions, and add the secret code in section Shared Secrets (for TURN REST API) (don't know if it's necessary or not)."

#Open port 8443 and 3478 TCP and UDP, because coturn use the both protocols.
# iptables -A ...

# Then start
#/etc/init.d/coturn restart

#Remove # in front of TURNSERVER_ENABLED=1
#/etc/init.d/coturn restart

#
# Step 5.6 - Video Calls app
#
# 1. Configure the shared-secret secret in admin-interface.
# 2. Configure $mydomain.tld:8443 in admin-interface for both stun and turn-server - don't prepend https:// 

#
# Video viewer app, unnecessary.

# Post config.
# "As of Firefox >= 36 you must append the domain being used to the allowed domains to access your screen. You do this by navigating to about:config, search for 'media.getusermedia.screensharing.allowed_domains', and append the domain to the list of strings. You can edit the field simply by double clicking on it. Ensure that you follow the syntax rules of the field."

# The 
#wget https://github.com/strukturag/spreed-webrtc
#mv 
#autogen.sh
#./configure
#make


# Step 5.9
#
# Nextant search: https://github.com/nextcloud/nextant/wiki

# Step 5.7
#
# Etherpad-Lite install see wiki.selfhosted.xyz for known-to-work procedure.
# Should use Debian-packaged nodejs and also create systemd service for the sake of restart-when failing.


# Step 5.8
#
# Ownpad
# occ app install command
# cp $nc/resources/config/mimetypemapping.dist.json config/mimetypemapping.json
# add these sed replace _comment5 with itself and two more lines.
# "pad": ["application/x-ownpad"],
# "calc": ["application/x-ownpad"],
# chown $htuser:$htgroup $nc/config/mimetypemapping.json
#sudo -u www-data php /var/www/$mydomain/nextcloud/occ -vvvv maintenance:mimetype:update-db --repair-filecache
#sudo -u www-data php /var/www/$mydomain/nextcloud/occ -v maintenance:mimetype:update-js
# Double-scan files
#sudo -u www-data php /var/www/$mydomain/nextcloud/occ -vvvv files:scan --all

# Step 5.9
#
# OpenLDAP
# Ref: http://linoxide.com/linux-how-to/install-openldap-phpldapadmin-nginx-server/
# Secondary ref: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-a-basic-ldap-server-on-an-ubuntu-12-04-vps
:<<EOF
 apt-get install slapd ldap-utils
 dpkg-reconfigure slapd
 omit server configuration - no
 dns domain-name $mydomain.$tld
 organization name: $mydomain
 database backend to use: HDB
 remove the database when slapd is purged? no
 move old database out of the way? yes
 Not asked this: "Allow LDAPv2 protocol? No" but could have been.
EOF
# Install phpldapadmin from Debian sid which can use php7
#cd /tmp && wget http://ftp.se.debian.org/debian/pool/main/p/phpldapadmin/phpldapadmin_1.2.2-6_all.deb

http://ftp.se.debian.org/debian/pool/main/p/phpldapadmin/phpldapadmin_1.2.2-5.2_all.deb
#Don't: dpkg -i phpldapadmin_1.2.2-5.2_all.deb

# Configure phpldapadmin on the following lines in /etc/phpldapadmin/config.php
# $servers->setValue('server','host','127.0.0.1');
# leave at 127.0.0.1
#$servers->setValue('server','base',array('dc=example,dc=com'));
# set to 'dc=$mydomain,dc=$tld'
#$servers->setValue('login','bind_id','cn=admin,dc=example,dc=com');
# set to 'dc=$mydomain,dc=$tld'
#Should be set to true: $servers->setValue('server','tls',true);
# See /etc/nginx/sites-available/default for phpldap-admin configuration.
#chown www-data:www-data -R /usr/share/phpldapadmin/



# Step 5.2
#
# Two-factor authentication
# See here: https://docs.nextcloud.com/server/10/admin_manual/configuration_server/occ_command.html#command-line-installation-label
# Just occ-enable it since it's official app.
# echo "If you decide to use this you should know that I have tested and recommend using the GPLv3-licensed app called Android Token hosted on f-droid." 

# Step 5.3
#
# Mail-app
:<<EOF

# set
'app.mail.imaplog.enabled' => true,
'app.mail.smtplog.enabled' => true,
'app.mail.imap.timeout' => 20,
'app.mail.smtp.timeout' => 2,
 possibly 'app.mail.transport' => 'php-mail'

EOF

# Step 5.4
#
# Audio music player - 3rd party app
# command line usage of the app, ref: https://github.com/Rello/audioplayer/wiki/OCC-Command-Line

#Add to config/mimetypemapping.json unless they already exist (which they do by default in nc 11.02.
:<<EOF
"mp3": ["audio/mpeg"],
"ogg": ["audio/ogg"],
"opus": ["audio/ogg"],
"wav": ["audio/wav"],
"m4a": ["audio/mp4"],
"m4b": ["audio/mp4"],
EOF

# Update MIME-TYPES. Below from https://github.com/rello/audioplayer/wiki/audio-files-and-mime-types
# "You have to update the table *PREFIX*mimetypes with the newly added MIME types and correct the file mappings in the table *PREFIX*filecache with occ command ./occ maintenance:mimetype:update-db --repair-filecache as well as the core/js/mimetypelist.js with command ./occ maintenance:mimetype:update-js.

# sudo -u $htuser php $nc/occ -vvvv maintenance:mimetype:update-db --repair-filecache
# sudo -u $htuser php $nc/occ -v maintenance:mimetype:update-js

# Step 5.5 
#
# Weather App - 3rd party app
# Requires registration for API access: http://openweathermap.org/price
# install just by enabling. https://github.com/nextcloud/weather

# news updater installation
# apt-get install python3-pip
# pip3 install nextcloud_news_updater --install-option="--install-scripts=/usr/bin"
# to crontab: "*/15 * * * * sudo -u www-data nextcloud-news-updater /var/www/example.com/nextcloud --mode singlerun &
