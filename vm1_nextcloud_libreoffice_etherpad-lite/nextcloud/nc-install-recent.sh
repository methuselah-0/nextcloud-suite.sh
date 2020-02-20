#!/bin/bash

mydomain="example.com"
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

### Step 1
#
do_Download_And_Unpack_Nextcloud(){
    cd $nc && wget $ncurl
    unzip $ncfile && ls
}
do_Nextcloud_Install(){
### Alternative all-in-one for new installs If-fresh machine statement then use this:
#
# reference https://docs.nextcloud.com/server/10/admin_manual/installation/command_line_installation.html
# detailed ref: https://docs.nextcloud.com/server/10/admin_manual/configuration_server/occ_command.html#command-line-installation-label
#chown -R $htuser:$htgroup $nc
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
}

do_Configure_PHP(){
### Step 3
#
# Configure PHP7
# /etc/php/7.0/fpm/pool.d/www.conf uncomment these:
#;env[HOSTNAME] = $HOSTNAME
#;env[PATH] = /usr/local/bin:/usr/bin:/bin
#;env[TMP] = /tmp
#;env[TMPDIR] = /tmp
#;env[TEMP] = /tmp
# also change default pm.max_children = 5 to pm.max_children = 40 

# /etc/php/7.0/php.ini
#Sed or cat this. If you wanna change default maximum file upload size etc you can set it to maximum size 5 gigabyte.
# http://php.net/manual/en/ini.core.php#ini.post-max-size
# http://php.net/manual/en/ini.core.php#ini.upload-max-filesize
    # This one in cloud.conf:
    client_max_body_size 30G;
    # The below two in php.ini in /etc/php/7.0/cli/php.ini:
    # figure out how to comment previousline and add to below newline instead of replacing as below.
    sed -i 's/post_max_size.*/post_max_size = 32G;/' /etc/php/7.0/cli/php.ini
    sed -i 's/upload_max_filesize.*/upload_max_filesize = 30G;/' /etc/php/7.0/cli/php.ini

    # Finally, edit /var/www/example.com/nextcloud/.user.ini
    # memory_limit to 5G as well as above two again.
    do_Setup_Opcache_etc(){
cat << EOF >> /etc/php/7.0/mods-available/opcache.ini
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1 ; "Basically put, how often (in seconds) should the code cache expire and check if your code has changed. 0 means it checks your PHP code every single request (which adds lots of stat syscalls). Set it to 0 in your development environment. Production doesn't matter because of the next setting."
opcache.validate_timestamps ; "When this is enabled, PHP will check the file timestamp per your opcache.revalidate_freq value. When it's disabled, opcache.revaliate_freq is ignored and PHP files are NEVER checked for updated code. So, if you modify your code, the changes won't actually run until you restart or reload PHP (you force a reload with kill -SIGUSR2). Yes, this is a pain in the ass, but you should use it. Why? While you're updating or deplying code, new code files can get mixed with old ones— the results are unknown. It's unsafe as hell."
; source https://github.com/nextcloud/documentation/issues/450

EOF
    systemctl restart php7.0-fpm
    systemctl restart nginx
    }
    do_Setup_Opcache_etc
}

do_Post_Install_Configuration(){
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
# Also enable local memcaching
    # 'memcache.local' => '\OC\Memcache\APCu',


    # possibly fix .user.ini file in nextcloud root
    cat <<EOF > ${nc}/.user.ini
#upload_max_filesize=511M
upload_max_filesize=30G
#post_max_size=511M
post_max_size=32G
#memory_limit=512M
memory_limit=5G
mbstring.func_overload=0
always_populate_raw_post_data=-1
default_charset='UTF-8'
output_buffering=0
EOF
}

do_Fix_Permissions(){
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
EOF
}


# FINALLY 
# Ask to Install Common Apps
#
# Introduce official apps first, then 3rd party ones with mention of stability risk.
# Step 5.3 LibreofficeOnline, see other script.

