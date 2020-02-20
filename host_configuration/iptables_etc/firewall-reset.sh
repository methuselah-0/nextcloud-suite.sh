#!/bin/bash
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
# Flush nat and mangle tables
iptables -t nat -F
iptables -t mangle -F
# Flush all chains
iptables -F
# Delete all non-default chains
iptables -X
