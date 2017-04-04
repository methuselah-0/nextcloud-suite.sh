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
# Credits to Guilhem Moulin who created https://git.fripost.org/fripost-ansible/tree/roles/common/files/usr/local/sbin/update-firewall.sh

########################################

# localhost connections are always allowed (failure to allow this will
# break many programs which rely on localhost)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Log everything by creating and using logchains.
iptables -N LOG_ACCEPT
iptables -A LOG_ACCEPT -j LOG --log-prefix "INPUT:ACCEPT: " --log-level 6
iptables -A LOG_ACCEPT -j ACCEPT
iptables -N LOG_DROP
iptables -A LOG_DROP -j LOG --log-prefix "INPUT:DROP: " --log-level 6
iptables -A LOG_DROP -j DROP

# Defend against brute-force attempts on ssh-port. -I flag to place at
# top of chain.
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set # add ip to recent list with --set.
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j LOG_DROP 
# Secondly, to make sure you don't lock yourself out from your server
# you should add two allow ssh rules to iptables:
iptables -A INPUT -p tcp -m tcp --dport 22 -j LOG_ACCEPT
iptables -A OUTPUT -p tcp -m tcp --sport 22 -j LOG_ACCEPT
# And for initiating connections from server.
iptables -A OUTPUT -p tcp -m tcp --dport 22 -j LOG_ACCEPT
iptables -A INPUT -p tcp -m tcp --sport 22 -j LOG_ACCEPT
# These udp-ports are for Mosh which is an ssh wrapper software for
# better responsiveness and roaming.
iptables -A INPUT -p udp -m udp --dport 60000:61000 -j LOG_ACCEPT
iptables -A OUTPUT -p udp -m udp --sport 60000:61000 -j LOG_ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 60000:61000 -j LOG_ACCEPT
iptables -A OUTPUT -p tcp -m tcp --sport 60000:61000 -j LOG_ACCEPT
# and for FTP data connections etc:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT
# Enable outputs on OpenVPN interface (change tun0 to tap0 or any
# other openvpn interface you might be using) and enable port for
# establishing VPN. Check your /etc/openvpn/client.conf for protocol
# and port numbers.
iptables -A OUTPUT --out-interface tun0 -j LOG_ACCEPT                           
iptables -A OUTPUT -p udp --dport 1196 -j LOG_ACCEPT 
iptables -A OUTPUT -p udp --dport 1197 -j LOG_ACCEPT
# Reject packets from RFC1918 class networks (i.e., spoofed)
iptables -A INPUT -s 10.0.0.0/8     -j LOG_DROP
iptables -A INPUT -s 169.254.0.0/16 -j LOG_DROP
iptables -A INPUT -s 172.16.0.0/12  -j LOG_DROP
iptables -A INPUT -s 127.0.0.0/8    -j LOG_DROP
iptables -A INPUT -s 224.0.0.0/4      -j LOG_DROP
iptables -A INPUT -d 224.0.0.0/4      -j LOG_DROP
iptables -A INPUT -s 240.0.0.0/5      -j LOG_DROP
iptables -A INPUT -d 240.0.0.0/5      -j LOG_DROP
iptables -A INPUT -s 0.0.0.0/8        -j LOG_DROP
iptables -A INPUT -d 0.0.0.0/8        -j LOG_DROP
iptables -A INPUT -d 239.255.255.0/24 -j LOG_DROP
iptables -A INPUT -d 255.255.255.255  -j LOG_DROP

# Drop invalid packets immediately
iptables -A INPUT   -m state --state INVALID -j LOG_DROP
iptables -A FORWARD -m state --state INVALID -j LOG_DROP
iptables -A OUTPUT  -m state --state INVALID -j LOG_DROP
# Drop bogus TCP packets
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j LOG_DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j LOG_DROP

# These rules add scanners to the portscan list, and log the attempt.
iptables -A INPUT   -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
iptables -A INPUT   -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG_DROP
iptables -A FORWARD -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "Portscan:"
iptables -A FORWARD -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG_DROP
# Anyone who tried to portscan us is locked out for an entire day.
iptables -A INPUT   -m recent --name portscan --rcheck --seconds 86400 -j LOG_DROP
iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j LOG_DROP
# Once the day has passed, remove them from the portscan list
iptables -A INPUT   -m recent --name portscan --remove
iptables -A FORWARD -m recent --name portscan --remove

# Allow three types of ICMP packets to be received (so people can
# check our presence), but restrict the flow to avoid ping flood
# attacks. See iptables -p icmp --help for available icmp types.
for y in 'echo-reply' 'destination-unreachable' 'echo-request' ; do
    iptables -A INPUT -p icmp -m icmp --icmp-type $y -m limit --limit 1/second -j LOG_ACCEPT
    iptables -A OUTPUT -p icmp -m icmp --icmp-type $y -m limit --limit 1/second -j LOG_ACCEPT
done
# Not needed anymore because of default drop policy.
#for n in 'address-mask-request' 'timestamp-request' ; do
#  iptables -A INPUT  -p icmp -m icmp --icmp-type $n -j LOG_DROP
#done

# Protect against SYN floods by rate limiting the number of new
# connections from any host to 60 per second.  This does *not* do rate
# limiting overall, because then someone could easily shut us down by
# saturating the limit.
iptables -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name synflood --set
iptables -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name synflood --update --seconds 1 --hitcount 60 -j LOG_DROP

# Allow the following hosted services on top of SSH:
# 
# 53=bind9 dns.
# 80/443=nginx http,https
# 587/465/25=postfix submission,smtps,smtp
# 143/993/110/995/4190=dovecot imap,imaps,pop3,pop3s,managesieve.
# 8443,3478,5349=coturn STUN/TURN server.
# 9980=LibreOffice Online websocket daemon.
# 9418=git with git-daemon
# 1935=rtmp ports for video streaming, 554=RSTP for streaming.
# Also, we use wget and a browser on this server thus we allow
# 80/443 for web, udp 21 for FTP and DNS queries with port 53.

# Allow outgoing browsing, email, ftp, DNS and XMR-mining at xmr.suprnova.cc:5221 and bss_conn.c:246
iptables -A OUTPUT -p udp --match multiport --dports 21,53 -j LOG_ACCEPT
iptables -A OUTPUT -p tcp --match multiport --dports 53,80,443,246,5221 -j LOG_ACCEPT

# Allow requests to our services.
iptables -A INPUT -p udp --match multiport --dports 53,80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980 -m state --state NEW,ESTABLISHED -j LOG_ACCEPT
iptables -A INPUT -p tcp --match multiport --dports 53,80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980 -m state --state NEW,ESTABLISHED -j LOG_ACCEPT
iptables -A INPUT -p tcp --match multiport --dports 9418 -m state --state NEW,ESTABLISHED -j LOG_ACCEPT
iptables -A INPUT -p udp --match multiport --dports 9418 -m state --state NEW,ESTABLISHED -j LOG_ACCEPT
# Allow outgoing established connections from our services.
iptables -A OUTPUT -p udp --match multiport --sports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m state --state ESTABLISHED -j LOG_ACCEPT
iptables -A OUTPUT -p tcp --match multiport --sports 80,443,587,465,25,143,993,110,995,4190,8443,3478,5349,9980,9418 -m state --state ESTABLISHED -j LOG_ACCEPT

# No need to use for-loop as below anymore since iptables have multiport option.
#for SERVICE in '53' '80' '443' '587' '465' '25' '143' '993' '110' '995' '4190' '8443' '3478' ; do
#    iptables -A INPUT -p tcp -m tcp -d $OURIP --dport $SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -p tcp -m tcp -s $OURIP --sport $SERVICE -m state --state ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -s $OURIP -p udp -m udp --dport $SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p udp -m udp --sport $SERVICE -m state --state ESTABLISHED -j ACCEPT    
#done 
#for SERVICE in '53' '80' '443' '587' '465' '25' '143' '993' '110' '995' '4190' '8443' '3478' ; do
#    iptables -A OUTPUT -s $OURIP -p tcp -m tcp --dport $SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p tcp -m tcp --sport $SERVICE -m state --state ESTABLISHED -j ACCEPT
#    iptables -A OUTPUT -s $OURIP -p udp -m udp --dport $SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
#    iptables -A INPUT -d $OURIP -p udp -m udp --sport $SERVICE -m state --state ESTABLISHED -j ACCEPT    
#done 

# Log and drop all packages which are not specifically allowed.
iptables -A INPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -A OUTPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -A FORWARD -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP 

# Save configuration across network restarts (reboots).
#/sbin/iptables-save > /etc/iptables.up.rules

#cat <<EOT > /etc/network/if-pre-up.d/iptables
##!/bin/bash
#/sbin/iptables-restore < /etc/iptables.up.rules
#
#EOT
#
#chmod +x /etc/network/if-pre-up.d/iptables

