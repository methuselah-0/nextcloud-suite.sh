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

########################################

# localhost connections are always allowed (failure to allow this will
# break many programs which rely on localhost)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Log everything by creating and using logchains.
iptables -N LOG_ACCEPT
iptables -A LOG_ACCEPT -j LOG --log-prefix "iptables: ACCEPT " --log-level 6
iptables -A LOG_ACCEPT -j ACCEPT
iptables -N LOG_DROP
iptables -A LOG_DROP -j LOG --log-prefix "iptables: DROP " --log-level 6
iptables -A LOG_DROP -j DROP

# create /etc/rsyslog.d/iptables.conf with
#: <<EOF
mkdir -p /etc/rsyslog.d/
touch /etc/rsyslog.d/iptables.conf
cat <<EOT > /etc/rsyslog.d/iptables.conf
:msg, startswith, "iptables: " -/var/log/iptables.log
& ~
:msg, regex, "^\[ *[0-9]*\.[0-9]*\] iptables: " -/var/log/iptables.log
& ~
EOT
#EOF
/usr/bin/iptables restart

# # Allow initiating ssh to this client but defend against brute-force
# # attempts on the ssh-port.
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set # adds ip to recent list with --set.
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j LOG_DROP
iptables -A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j LOG_ACCEPT
iptables -A OUTPUT -p tcp -m tcp --sport 22 -j LOG_ACCEPT
# These udp-ports are for Mosh which is an ssh wrapper software for
# better responsiveness and roaming.
iptables -A INPUT -p udp -m udp --dport 60000:61000 -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_ACCEPT 
iptables -A OUTPUT -p udp -m udp --sport 60000:61000 -j LOG_ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 60000:61000 -m conntrack --ctstate RELATED,ESTABLISHED -j LOG_ACCEPT
iptables -A OUTPUT -p tcp -m tcp --sport 60000:61000 -j LOG_ACCEPT

# And for FTP data connections and everything else auto-identified as
# a related connection:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j LOG_ACCEPT
# Allow everything outgoing.
iptables -P OUTPUT LOG_ACCEPT
# Log and drop all incoming packages which are not specifically allowed
iptables -A INPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -P INPUT DROP
# Also, we are not a router.
iptables -A FORWARD -s 0.0.0.0/0 -d 0.0.0.0/0 -j LOG_DROP
iptables -P FORWARD DROP

# FOR ARCH LINUX ONLY: Save configuration across network restarts and reboots.
touch /etc/iptables/iptables.rules
iptables-save > /etc/iptables/iptables.rules


