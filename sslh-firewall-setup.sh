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

#SSLH SETUP
localsship=192.168.1.10
iptables -t mangle -N SSLH
# This host receives incoming connections on it's public IP that's on tun0 (VPN).
iptables -t mangle -I OUTPUT --protocol tcp --out-interface tun0 --sport 22 --jump SSLH
iptables -t mangle -I OUTPUT --protocol tcp --out-interface tun0 --sport 4443 --jump SSLH
#iptables -t mangle -I OUTPUT --protocol tcp --sport 4443 --jump SSLH
#iptables -t mangle -I SSLH  --protocol tcp -d $localsship --sport 22 --jump ACCEPT
#iptables -t mangle -I SSLH  --protocol tcp -s $localsship --jump ACCEPT
iptables -t mangle -A SSLH --jump MARK --set-mark 0x1
iptables -t mangle -A SSLH --jump ACCEPT
ip rule add fwmark 0x1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100
