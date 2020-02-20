# COTURN INSTALLATION & CONFIGURATION
#
# # STUN/TURN-REF(not using): https://github.com/coturn/coturn/wiki/turnadmin
#
apt-get install coturn

#
# Configure 1.
#
#/etc/turnserver.conf should look like
authpass="$(openssl rand -hex 32)"
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



# Someone used "MyDnsService" instead of $clouddomain before, see ref2.
# use if quotes in cat eot don't work.
#sed authpass
#sed mydomain

# create a turn-admin user
sudo turnadmin -A -u $turnadmin -p $turnadminpass
echo "The admin panel of coturn is available by browser at the adress : https://mynextcloud:8443 wich allows you to see the sessions, and add the secret code in section Shared Secrets (for TURN REST API) (don't know if it's necessary or not)."

#Open port 8443 and 3478 TCP and UDP, because coturn use the both protocols.
# iptables -A ...

#
# Configure 2 - /etc/default/coturn
#
# Run /etc/turnserver.conf as a service by uncommenting TURNSERVER_ENABLED=1
sed 's/TURNSERVER_ENABLED=0/TURNSERVER_ENABLED=1/g' /etc/default/coturn
# logfile
#sed /etc/turnserver.conf
chown $htuser:$htgroup /var/log/turn.log

# Then start
/etc/init.d/coturn restart

turnadmin -A -u admin -p passwordtochange

#
