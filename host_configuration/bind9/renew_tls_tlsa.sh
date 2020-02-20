#!/bin/bash
set -e
#certbot certonly --duplicate --redirect --hsts --webroot --dry-run \
#  -w /home/letsencrypt/ -d pad.example.com \
#                        -d example.com \
#                        -d myserverhost.example.com \
#			-d shop.example.com \
#			-d sip.example.com \
#			-d social.example.com \
#			-d xmpp.example.com \
#			-d blog.example.com \
#			-d cctv.example.com \
#			-d cloud.example.com \
#			-d irc.example.com \
#			-d search.example.com \
#			-d office.example.com \
#			-d maps.example.com \
#			-d media.example.com \
#			-d piwik.example.com \
#  -w /var/www/mail/rc/  -d webmail.example.com \
#  -w /usr/share/dokuwiki/ -d wiki.example.com \
#  -w /var/www/mail/ -d mail.example.com \
# --dry-run \

certpath="/etc/letsencrypt/live/example.com/cert.pem"
chainpath="/etc/letsencrypt/live/example.com/chain.pem"
fullchainpath="/etc/letsencrypt/live/example.com/fullchain.pem"
keypath="/etc/letsencrypt/live/example.com/privkey.pem"
zonefile='/etc/bind/db.example.com'
domain="example"
tld="come"
oldhash="$(cat "$zonefile" | grep "${domain}"."${tld}" | grep TLSA | tail -n 1 | awk ' { print $7 } ')"

# for libreoffice-online
looluser="lool"
loolgroup="lool"
saveNginx(){
    mkdir -p /tmp/nginx_enabled_conf_files/
    mv /etc/nginx/sites-enabled/* /tmp/nginx_enabled_conf_files/
}

installAcmeChallengeConfiguration(){
cat <<EOF > /etc/nginx/snippets/letsencryptauth.conf
location /.well-known/acme-challenge {
    alias /etc/letsencrypt/webrootauth/.well-known/acme-challenge;
    location ~ /.well-known/acme-challenge/(.*) {
    add_header Content-Type application/jose+json;
    }
}
EOF

cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /etc/letsencrypt/webrootauth;
    include snippets/letsencryptauth.conf;
}
EOF
service nginx reload
sleep 1
}

getCerts(){
certbot certonly --duplicate --redirect --hsts --staple-ocsp --webroot -w /etc/letsencrypt/webrootauth -d example.com -d www.example.com -d myserverhost.example.com -d analytics.example.com -d blog.example.com -d cctv.example.com -d cloud.example.com -d irc.example.com -d maps.example.com -d media.example.com -d office.example.com -d piwik.example.com -d pad.example.com -d search.example.com -d shop.example.com -d social.example.com -d sip.example.com -d xmpp.example.com -d webmail.example.com -d wiki.example.com -d mail.example.com -d ldap.example.com -d portal.example.com -d manager.example.com -d reload.example.com -d test1.example.com -d test2.example.com -d ebw.example.com
}

#basepath="/etc/letsencrypt/live/${domain}"
#length=${#basepath}
#totlength=$(($length+5))

installNewCerts(){
    # here we are assuming that the path ending is on the form example.com-XXXX
    newcertdir="/etc/letsencrypt/live/"$(ls -l /etc/letsencrypt/live/ | tail -n 1 | awk ' {print $9} ')""
    ln -s -f $newcertdir/cert.pem $certpath
    ln -s -f $newcertdir/chain.pem $chainpath
    ln -s -f $newcertdir/fullchain.pem $fullchainpath
    ln -s -f $newcertdir/privkey.pem $keypath
#    echo "installed new certs"
}
# certpath=/etc/letsencrypt/live/example.com/cert.pem
# chainpath=/etc/letsencrypt/live/example.com/chain.pem
# fullchainpath=/etc/letsencrypt/live/example.com/fullchain.pem
# keypath=/etc/letsencrypt/live/example.com/privkey.pem
updateDNSSec(){
    newhash=$(tlsa_rdata $fullchainpath 3 1 1 | grep "3 1 1" | awk ' { print $4 } ')
    sed -i "s/$oldhash/$newhash/g" "${zonefile}"
    zone=""${domain}"."${tld}""
    zonesigner.sh "${zone}" "${zonefile}"
    systemctl restart bind9
}
restoreNginx(){
mv /tmp/nginx_enabled_conf_files/* /etc/nginx/sites-enabled/
}
updateLoolCerts(){
    cp /etc/letsencrypt/live/example.com/cert.pem /opt/online/etc/mykeys/cert1.pem
    cp /etc/letsencrypt/live/example.com/privkey.pem /opt/online/etc/mykeys/privkey1.pem    
    cp /etc/letsencrypt/live/example.com/fullchain.pem /opt/online/etc/mykeys/fullchain1.pem
    cp /etc/letsencrypt/live/example.com/chain.pem /opt/online/etc/mykeys/chain1.pem
    chown -R ${looluser}:${loolgroup} /opt/online/etc/mykeys/
}
restartWebServer(){
    systemctl restart nginx
}

main(){
    saveNginx
    installAcmeChallengeConfiguration
    getCerts
    installNewCerts
    updateDNSSec
    restoreNginx
    updateLoolCerts
    restartWebServer
}
main
