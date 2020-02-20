#!/bin/bash
do_Setup_Xmpp_Server(){
    # http://prosody.im/doc/configure
    # consider adding a prosody.cfg.lua.in file in this repo instead.
    cat << EOF >> /etc/prosody/prosody.cfg.lua
VirtualHost "mydomain.tld"
        enabled = true
--        ssl = {
--                key = "/etc/letsencrypt/live/mydomain.tld/privkey.pem";
--                certificate = "/etc/letsencrypt/live/mydomain.tld/fullchain.pem";
--	}
EOF
    EOF <<EOF
    # http://prosody.im/doc/modules/mod_tls
    Also add and comment out
    -- c2s_require_encryption = false     
    --c2s_require_encryption = true
    --s2s_require_encryption = true
    -- s2s_secure_auth = false
    # http://prosody.im/doc/s2s#security
    --s2s_secure_auth = true
    # then instead use web https by adding
    consider_bosh_secure = true
    cross_domain_bosh = true
    # then uncomment or add in modules_enabled = { section
    "bosh"; -- Enable BOSH clients, aka "Jabber over HTTP"
    # bosh configuration: -- added by me
    http://prosody.im/doc/setting_up_bosh?s[]=bosh
    # add below the commented
    --"http_files";
    "http_files";
    # and then interface
    FIXTHIS
    -- added by me
    bosh_ports = {
                     {
                        port = 5280;
                        path = "http-bind";
    --                    interface = "123.456.789.123";
                        interface = "localhost";
                        ssl = {
                                key = "/etc/letsencrypt/live/mydomain.tld/privkey.pem";
                                certificate = "/etc/letsencrypt/live/mydomain.tld/fullchain.pem";
                              }
                     }
                 }
    # nginx
            location /http-bind {
                proxy_pass  http://localhost:5280/http-bind;
                proxy_set_header Host $host;
                proxy_buffering off;
                tcp_nodelay on;
            }
    ln -s /etc/nginx/sites-available/xmpp.conf /etc/nginx/sites-enabled/xmpp.conf
    systemctl restart prosody
    systemctl restart nginx
    prosodyctl register myusername cloud.mydomain.tld mypassword
    "systemctl restart prosody" after openvpn restart in crontab
    # postconfig in admin section is
    xmpp domain: cloud.mydomain.tld
    bosh url: https://cloud.mydomain.tld/http-bind
    xmpp resource: mydomain.tld
    turn secret is from /etc/turnserver.conf shared_secret_secret
    turn ttl is probably 600
    turn url is turn:cloud.mydomain.tld:5349
EOF
}
do_Setup_Ldap(){
    apt-get install mercurial lua-ldap
    cd /etc/prosody && hg clone https://hg.prosody.im/prosody-modules/ prosody-modules
#    authentication = "ldap" # comment "internal_plain" line
    #    ldap_base = "ou=people,dc=example,dc=com"
    "auth_ldap"; # in modules_enabled
    #and:
    #-- These paths are searched in the order specified, and before the default path
    #plugin_paths = { "/path/to/modules", "/path/to/more/modules" }
    plugin_paths = { "/etc/prosody/prosody-modules/" }
}
do_Setup_Ldap_Cyrus(){
    apt-get install sasl2-bin libsasl2-modules-ldap lua-ldap lua-cyrussasl
cat <<EOF > /etc/default/saslauthd
START=yes
MECHANISMS="ldap"
MECH_OPTIONS="/etc/saslauthd.conf"
EOF
cat <<EOF > /etc/saslauthd.conf
ldap_servers: ldap://ldap.example.com:389
ldap_search_base: ou=users,dc=example,dc=com
ldap_bind_dn: cn=admin,dc=example,dc=com
ldap_password: mysecretpassword
ldap_filter: (&(uid=%u)(objectClass=posixAccount))
ldap_group_attr: memberUid
ldap_group_match_method: filter
ldap_group_filter: (&(objectClass=posixGroup)(|(gidNumber=501))(memberUid=%u))
ldap_group_search_base: ou=groups,dc=example,dc=com
EOF
testsaslauthd -u someuser -p somepass
}
do_Setup_Ldap2(){
    ln -s /etc/prosody/prosody-modules/mod_lib_ldap/ldap.lib.lua /usr/lib/prosody/modules/ldap.lib.lua
    ln -s /etc/prosody/prosody-modules/mod_lib_ldap/ldap.lib.lua /usr/lib/prosody/modules/mod_lib_ldap.lua
    # weird thing but this required removal - http://linuxadmin.melberi.com/2013/07/auxpropfunc-error-invalid-parameter.html
    apt-get remove --purge libsasl2-modules-ldap
}
#usermod -a -G sasl prosody
main(){
    do_Setup_Ldap_Cyrus
}
#main
