#!/bin/bash
cd /opt
git clone https://github.com/cjdelisle/cjdns.git
cd cjdns
./do
ln -s /opt/cjdns/cjdroute /usr/bin
#(umask 077 && ./cjdroute --genconf > /etc/cjdroute.conf)
cp contrib/systemd/cjdns.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable cjdns
systemctl start cjdns
