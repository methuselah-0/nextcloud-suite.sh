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

# This software is based on another script, but most of it is different.
# Credits to Guilhem Moulin who wrote https://git.fripost.org/fripost-ansible/tree/roles/common/files/usr/local/sbin/update-firewall.sh

################################################################################
#
# Example usage (must be run from it's source directory):
# in case of running local nameserver: echo "nameserver 46.227.67.134" >> /etc/resolv.conf first
# or the ovpn connection might not be restorable.
# iptables --flush && ./firewall-setup-server sslh ipset && systemctl restart openvpn-client@ovpn.service
#
# Running with sslh option will assume local ssh source port 22 and
# ssl source port 4443.
################################################################################

localif="eth0"
pubif="tun0"
pwd="$(pwd)"
whitelist=(192.168.0.0/16 94.23.0.0/16)

iptables -P OUTPUT -j ACCEPT
iptables --flush
iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -P INPUT DROP

# localhost connections are always allowed (failure to allow this will
# break many programs which rely on localhost)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Log everything by creating and using logchains. The first five
# packets are allowed to exceed the five packets per minute, then the
# limiting kicks in. If there is a pause, another burst is allowed but
# not past the maximum rate set by the rule

iptables -N LOG_ACCEPT
iptables -A LOG_ACCEPT -m limit --limit 5/m --limit-burst 10 -j NFLOG --nflog-group 0 --nflog-prefix "ACCEPT "
# -j LOG --log-prefix "iptables: ACCEPT " --log-level 4
iptables -A LOG_ACCEPT -j ACCEPT
iptables -N LOG_DROP
iptables -A LOG_DROP -m limit --limit 5/m --limit-burst 10 -j NFLOG --nflog-group 0 --nflog-prefix "DROP "
# -j LOG --log-prefix "iptables: DROP " --log-level 4
iptables -A LOG_DROP -j DROP

# Only use this if not using ulogd.
# create /etc/rsyslog.d/iptables.conf with
#: <<EOF
#cat <<EOT > /etc/rsyslog.d/iptables.conf
#:msg, startswith, "iptables: " -/var/log/iptables.log
#& stop
#:msg, regex, "^\[ *[0-9]*\.[0-9]*\] iptables: " -/var/log/iptables.log
#& stop
#EOT
#EOF

# Defend against brute-force attempts on ssh-port. -I flag to place at
# top of chain.
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set -m comment --comment "Limit SSH IN" # add ip to recent list with --set.
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 -j LOG_DROP -m comment --comment "Limit SSH IN"
# Secondly, to make sure you don't lock yourself out from your server
# you should add two allow ssh rules to iptables first thing:
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT -m comment --comment "SSH IN"
iptables -A OUTPUT -p tcp -m tcp --sport 22 -j ACCEPT -m comment --comment "SSH OUT"
# These udp-ports are for Mosh which is an ssh wrapper software for
# better responsiveness and roaming.
iptables -A INPUT -p udp -m udp --dport 60000:61000 -j LOG_ACCEPT -m comment --comment "Mosh UDP IN"
iptables -A OUTPUT -p udp -m udp --sport 60000:61000 -j LOG_ACCEPT -m comment --comment "Mosh UDP OUT"
#iptables -A INPUT -p tcp -m tcp --dport 60000:61000 -j LOG_ACCEPT -m comment --comment "Mosh TCP IN"
#iptables -A OUTPUT -p tcp -m tcp --sport 60000:61000 -j LOG_ACCEPT -m comment --comment "Mosh TCP OUT"

# Enable outputs on OpenVPN interface (change tun0 to tap0 or any
# other openvpn interface you might be using) and enable port for
# establishing VPN. Check your /etc/openvpn/client.conf for protocol
# and port numbers.
#iptables -A OUTPUT --out-interface tun0 -j LOG_ACCEPT 
iptables -A OUTPUT -p udp --dport 1196 -j LOG_ACCEPT -m comment --comment "OVPN"
iptables -A OUTPUT -p udp --dport 1197 -j LOG_ACCEPT -m comment --comment "OVPN"

# Reject packets from RFC1918 class networks (i.e., spoofed)
iptables -A INPUT -s 10.0.0.0/8     -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 169.254.0.0/16 -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 172.16.0.0/12  -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 127.0.0.0/8    -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 224.0.0.0/4      -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -d 224.0.0.0/4      -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 240.0.0.0/5      -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -d 240.0.0.0/5      -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -s 0.0.0.0/8        -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -d 0.0.0.0/8        -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -d 239.255.255.0/24 -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"
iptables -A INPUT -d 255.255.255.255  -j LOG_DROP -m comment --comment "RFC1918 class network - spoofed address"

# Drop invalid packets immediately
iptables -A INPUT   -m conntrack --ctstate INVALID -j LOG_DROP -m comment --comment "INVALID packet type"
iptables -A FORWARD -m conntrack --ctstate INVALID -j LOG_DROP -m comment --comment "INVALID packet type"
iptables -A OUTPUT  -m conntrack --ctstate INVALID -j LOG_DROP -m comment --comment "INVALID packet type"
# Drop bogus TCP packets
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j LOG_DROP -m comment --comment "Bogus tcp packet type"
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j LOG_DROP -m comment --comment "Bogus tcp packet type"

# These rules add scanners to the portscan list, and logs the attempt.
#iptables -A INPUT   -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
iptables -A INPUT   -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG_DROP -m comment --comment "Portscan"
#iptables -A FORWARD -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
iptables -A FORWARD -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG_DROP -m comment --comment "Portscan"
# Anyone who tried to portscan us is locked out for an entire day.
iptables -A INPUT   -m recent --name portscan --rcheck --seconds 86400 -j LOG_DROP -m comment --comment "Portscan: locking out for a day."
iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j LOG_DROP -m comment --comment "Portscan: locking out for a day."
# Once the day has passed, remove them from the portscan list
iptables -A INPUT   -m recent --name portscan --remove -m comment --comment "Portscan: remove a locked-out address after a day."
iptables -A FORWARD -m recent --name portscan --remove -m comment --comment "Portscan: remove a locked-out address after a day."

# Allow three types of ICMP packets to be received (so people can
# check our presence), but restrict the flow to avoid ping flood
# attacks. See iptables -p icmp --help for available icmp types.
for y in 'echo-reply' 'destination-unreachable' 'echo-request' ; do
    iptables -A INPUT -p icmp -m icmp --icmp-type $y -m limit --limit 1/second -j LOG_ACCEPT -m comment --comment "smurf-attack-protection"
    iptables -A OUTPUT -p icmp -m icmp --icmp-type $y -m limit --limit 1/second -j LOG_ACCEPT -m comment --comment "smurf-attack-protection"
done
# Not needed anymore because of default drop policy.
#for n in 'address-mask-request' 'timestamp-request' ; do
#  iptables -A INPUT  -p icmp -m icmp --icmp-type $n -j LOG_DROP
#done

# Protect against SYN floods by rate limiting the number of new
# connections from any host to 60 per second.  This does *not* do rate
# limiting overall, because then someone could easily shut us down by
# saturating the limit.
iptables -A INPUT -m conntrack --ctstate NEW -p tcp -m tcp --syn -m recent --name synflood --set
iptables -A INPUT -m conntrack --ctstate NEW -p tcp -m tcp --syn -m recent --name synflood --update --seconds 1 --hitcount 60 -j LOG_DROP -m comment --comment "synflood-protection"

# User connections: tcp ports for dns, browsing, email, XMR-mining at xmr.suprnova.cc:5221, bss_conn.c:246, and udp ports for ftp and DNS.
iptables -A OUTPUT -p udp --match multiport --dports 21,53 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "user-connection"
iptables -A OUTPUT -p tcp --match multiport --dports 22,53,80,443,246,5221 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "user-connection"

# Optional setups
f_do_ipsetSetup(){
cat <<EOF > /lib/systemd/system/ipset.service
[Unit]
Description=Loading IP Sets
Before=network-pre.target iptables.service ip6tables.service ufw.service
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ipset -f /etc/ipset.conf restore
ExecReload=/sbin/ipset -f /etc/ipset.conf restore
ExecStop=/sbin/ipset destroy

[Install]
WantedBy=multi-user.target
EOF
echo "running ./my-ipset-update.sh. May take some time."
./my-ipset-update.sh

whitelist(){
    for someList in "$(ipset list -n)"
    do for someSet in "${whitelist[@]}"
       do ipset del "$someList" "$someSet"
       done
    done
}
whitelist

ipset save > /etc/ipset.conf
systemctl daemon-reload
systemctl enable ipset
echo "finished ipsetSetup"
}

f_do_sslhSetup(){
    #SSLH SETUP
    # not used
    #localsship=192.168.1.10
    echo "Assuming you have sslh installed and setup; with local ssh source port 22 and ssl source port 4443."
    iptables -t mangle -N SSLH
    # This host receives incoming connections on it's public IP that's on tun0 (VPN).
    iptables -t mangle -I OUTPUT --protocol tcp --out-interface $pubif --sport 22 --jump SSLH
    iptables -t mangle -I OUTPUT --protocol tcp --out-interface $pubif --sport 4443 --jump SSLH
    #iptables -t mangle -I OUTPUT --protocol tcp --sport 4443 --jump SSLH
    #iptables -t mangle -I SSLH  --protocol tcp -d $localsship --sport 22 --jump ACCEPT
    #iptables -t mangle -I SSLH  --protocol tcp -s $localsship --jump ACCEPT
    iptables -t mangle -A SSLH --jump MARK --set-mark 0x1
    iptables -t mangle -A SSLH --jump ACCEPT
    # avoid duplicate fwmark
    if ! ip rule show | grep "fwmark 0x1 lookup 100" -q ; then ip rule add fwmark 0x1 lookup 100 ; fi
    ip route add local 0.0.0.0/0 dev lo table 100
    echo "finished sslhSetup"
}
cd $pwd
case $1 in
    "sslh") f_do_sslhSetup ;;
    "ipset") f_do_ipsetSetup ;;
    *) echo "No arguments given. Ok. Continuing."
esac
case $2 in
    "sslh") f_do_sslhSetup ;;
    "ipset") f_do_ipsetSetup ;;
    *) echo "No second argument given. Ok. Continuing."    
esac


# Allow requests to our services.
# Allow the following hosted services on top of SSH:
# 
# 53=bind9 dns.
# 80/443=nginx http,https
# 88=kerberos
# 389/636=ldap
# 587/465/25=postfix submission,smtps,smtp
# 143/993/110/995/4190=dovecot imap,imaps,pop3,pop3s,managesieve.
# 7825=smbd/samba but this is not in use at the moment.
# 8443,3478,5349=coturn STUN/TURN server. 8443 is tls.
# 9980=LibreOffice Online websocket daemon.
# 9418=git with git-daemon
# 1935=rtmp ports for video streaming, 554=RSTP for streaming.
#iptables -A INPUT -p tcp --match multiport --dports 8443,3478,5349 -j ACCEPT
#iptables -A INPUT -p udp --match multiport --dports 8443,3478,5349 -j ACCEPT
#iptables -A OUTPUT --match multiport --dports 8443,3478,5349 -j ACCEPT
iptables -A INPUT -p udp --match multiport --dports 53,80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-request" 
iptables -A INPUT -p tcp --match multiport --dports 53,80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-request"

iptables -A INPUT -p tcp --match multiport --dports 9418 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection"
iptables -A INPUT -p udp --match multiport --dports 88,9418 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection"
# Allow local udp port 5353 for multicast DNS on local network port (avahi-daemon)
iptables -A INPUT -p udp --in-interface ${localif} --dport 5353 -j LOG_ACCEPT -m comment --comment "multicast-dns"
iptables -A INPUT -p tcp --in-interface ${localif} --dport 389 -j LOG_ACCEPT -m comment --comment "ldap"

# Allow local outgoing multicast DNS connections
iptables -A OUTPUT -p udp --out-interface ${localif} -d 224.0.0.251 --dport 5353 -j LOG_ACCEPT -m comment --comment "multicast-dns"
# Specifically allow outgoing established connections from our services. (This should be taken care of automatically by above statement)
iptables -A OUTPUT -p udp --match multiport --sports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m conntrack --ctstate ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-reply"
iptables -A OUTPUT -p tcp --match multiport --sports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m conntrack --ctstate ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-reply"
# Allow opening new connections on these same services from server.
iptables -A OUTPUT -p udp --match multiport --dports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-reply"
iptables -A OUTPUT -p udp --dport 123 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "ntp - network time protocol"
iptables -A OUTPUT -p tcp --match multiport --dports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "service-connection-reply"
iptables -A OUTPUT -p tcp --dport 2703 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT -m comment --comment "razor, spamassasin stuff"

# Allow everything auto-identified as a related connection:
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j LOG_ACCEPT 
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j LOG_ACCEPT 

# No need to use for-loop as below anymore since iptables have multiport option (although max 15 entries).
#for SERVICE in '53' '80' '443' '587' '465' '25' '143' '993' '110' '995' '4190' '8443' '3478' ; do
#    iptables -A INPUT -p tcp -m tcp -d $OURIP --dport $SERVICE -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -p tcp -m tcp -s $OURIP --sport $SERVICE -m conntrack --ctstate ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -s $OURIP -p udp -m udp --dport $SERVICE -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p udp -m udp --sport $SERVICE -m conntrack --ctstate ESTABLISHED -j ACCEPT    
#done 
#for SERVICE in '53' '80' '443' '587' '465' '25' '143' '993' '110' '995' '4190' '8443' '3478' ; do
#    iptables -A OUTPUT -s $OURIP -p tcp -m tcp --dport $SERVICE -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p tcp -m tcp --sport $SERVICE -m conntrack --ctstate ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -s $OURIP -p udp -m udp --dport $SERVICE -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p udp -m udp --sport $SERVICE -m conntrack --ctstate ESTABLISHED -j ACCEPT    
#done 

# Log and drop all packages which are not specifically allowed.
iptables -A INPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -A OUTPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -A FORWARD -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP 

# Save configuration across network restarts and reboots.
/sbin/iptables-save > /etc/iptables.up.rules
if [[ $1 == "sslh" ]] || [[ $2 == "sslh" ]] ; then
cat <<EOT > /etc/network/if-pre-up.d/iptables
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.up.rules
# for sslh
# avoid duplicate fwmark
if ! ip rule show | grep "fwmark 0x1 lookup 100" -q ; then ip rule add fwmark 0x1 lookup 100 ; fi
if ip route add local 0.0.0.0/0 dev lo table 100 ; then echo "ip route add local 0.0.0.0/0 dev lo table 100 was issued" ; fi
EOT
else
cat <<EOT > /etc/network/if-pre-up.d/iptables
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.up.rules

EOT
fi

chmod u+x /etc/network/if-pre-up.d/iptables

