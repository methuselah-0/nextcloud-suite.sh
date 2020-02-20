# admin & phpldapadmin
# install slapd before phpldapadmin - https://stackoverflow.com/questions/13921030/phpldapadmin-does-not-work-for-an-unknown-reason

# Lemonldap-ng


#With tarball installation, Nginx configuration files will be installed in /usr/local/lemonldap-ng/etc/, else they are in /etc/lemonldap-ng.

#You have to include them in Nginx main configuration.
#Debian/Ubuntu

lemonldap-ng-deps(){
    apt-get install libapache-session-perl libnet-ldap-perl libcache-cache-perl libdbi-perl perl-modules libwww-perl libcache-cache-perl libxml-simple-perl  libsoap-lite-perl libhtml-template-perl libregexp-assemble-perl libregexp-common-perl libjs-jquery libxml-libxml-perl libcrypt-rijndael-perl libio-string-perl libxml-libxslt-perl libconfig-inifiles-perl libjson-perl libstring-random-perl libemail-date-format-perl libmime-lite-perl libcrypt-openssl-rsa-perl libdigest-hmac-perl libdigest-sha-perl libclone-perl libauthen-sasl-perl libnet-cidr-lite-perl libcrypt-openssl-x509-perl libauthcas-perl libtest-pod-perl libtest-mockobject-perl libauthen-captcha-perl libnet-openid-consumer-perl libnet-openid-server-perl libunicode-string-perl libconvert-pem-perl libmoose-perl libplack-perl liblasso-perl
    apt-get install nginx nginx-extras
}

lemonldap_download_and_install(){ # download 1.9.10 tarball and unpack
    cd /opt && wget $llng_url
    tar zxvf lemonldap-ng-*.tar.gz
    cd lemonldap-ng-*
    # Build & Install
    make
    #make test
    make install
    apt-get install lemonldap-ng-fastcgi-server # to get the systemd service for free.
    # Update your /etc/hosts to map SSO URLs to localhost:    
    cat /usr/local/lemonldap-ng/etc/for_etc_hosts >> /etc/hosts
    make postconf
    #lemonldap-set-domain-name
    #dpkg -i install liblemonldap*
    #dpkg -i install lemonldag-ng*
    #possibly cpan install Mouse necessary
    # possibly check INSTALL in tarball dir for more deps.
    #Enable and start the service :
    systemctl enable llng-fastcgi-server
    systemctl start llng-fastcgi-server
}
lemonldap-set-domain-name(){
    sed -i 's/auth\.example\.com/portal.selfhosted.xyz/g' /usr/local/lemonldap-ng/data/conf/lmConf-1.js /usr/local/lemonldap-ng/htdocs/test/index.pl  /etc/hosts
    sed -i 's/manager\.example\.com/manager.selfhosted.xyz/g' /usr/local/lemonldap-ng/data/conf/lmConf-1.js /usr/local/lemonldap-ng/htdocs/test/index.pl  /etc/hosts
    sed -i 's/reload\.example.com/reload.selfhosted.xyz/g' /usr/local/lemonldap-ng/data/conf/lmConf-1.js /usr/local/lemonldap-ng/htdocs/test/index.pl /etc/hosts
    sed -i 's/example.com/selfhosted.xyz/g' /usr/local/lemonldap-ng/data/conf/lmConf-1.js /usr/local/lemonldap-ng/htdocs/test/index.pl /etc/hosts    
    sed -i 's/http:/https:/g' /usr/local/lemonldap-ng/data/conf/lmConf-1.js /usr/local/lemonldap-ng/htdocs/test/index.pl 
    #trusted domains etc in /etc/lemonldap-ng/lemonldap-ng.ini /usr/local/lemonldap-ng/etc/lemonldap-ng.ini
}

do_Install_Nginx_Conf(){
    ln -s /etc/lemonldap-ng/handler-nginx.conf /etc/nginx/sites-available/
    ln -s /etc/lemonldap-ng/manager-nginx.conf /etc/nginx/sites-available/
    ln -s /etc/lemonldap-ng/portal-nginx.conf /etc/nginx/sites-available/
    ln -s /etc/lemonldap-ng/test-nginx.conf /etc/nginx/sites-available/
}

lemonldap_main(){
    # note: can't install debian packages since they make nginx complain about $lmremote_user
    #nginx: [emerg] unknown "lmremote_user" variable
    #nginx: configuration file /etc/nginx/nginx.conf test failed
    
    #lemonldap-ng-deps
    
    #lemonldap_download_and_install
    lemonldap-set-domain-name
    #do_Install_Nginx_Conf
}
lemonldap_main
phpldapadmin_main(){
    # installation: http://phpldapadmin.sourceforge.net/wiki/index.php/Installation
    apt-get install slapd
    cd /home/user1/Downloads/ && wget http://ftp.se.debian.org/debian/pool/main/p/phpldapadmin/phpldapadmin_1.2.2-6_all.deb
    dpkg -i phpldapadmin_1.2.2-6_all.deb
    apt-get install -f
cat <<EOF >> /etc/ldap/slapd.conf
moduleload memberof.la
overlay memberof
EOF
cat <<EOF >> /etc/ldap/slapd.d/memberOf.ldif
#contents of memberOf.ldif
dn: cn=vpn,ou=Groups,dc=shop,dc=lan
objectclass: groupofnames
cn: vpn
description: Users allowed to connect on VPN
member: uid=jordan,ou=People,dc=shop,dc=lan
EOF
slapadd -f /etc/ldap/slapd.d/memberOf.ldif
}


# notes on configuration
# ldap: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-a-basic-ldap-server-on-an-ubuntu-12-04-vps#AddOrganizationalUnits,Groups,andUsers
# ldapsearch -H ldap://ldap.selfhosted.xyz -b "dc=selfhosted,dc=xyz" -D "cn=admin,dc=selfhosted,dc=xyz" -w "mysecretpassword" -LLL

# for possible U2F see here: https://docs.nextcloud.com/server/10/admin_manual/configuration_server/occ_command.html#command-line-installation-label
