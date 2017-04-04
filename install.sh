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

# # # # # # # # # # # # # # # 
# These are global variables.
# You can edit variables for newer software versions at your own risk, domain-name, maxcon and maxdoc.
# The rest should be left as is. If you edit variable names anyway you have to edit systemd unit below as well.
maxcon=200
maxdoc=100
mydomain="secondleveldomain.tld" #should match /etc/letsencrypt/live/<secondleveldomain.tld> without a trailing '/'
adminuser="adminuser" # for the admin console which after install can be accessed at https://localhost:9980/dist/admin/admin.html
adminpass="adminpassword" 


# Don't edit the ones below.
#
# Rootdir is where server programs go.
rootdir="/opt"
# nc is where nextcloud rootdir goes, not used for now.
nc="/var/www/$mydomain/nextcloud"
soli="/etc/apt/sources.list"
loc="/opt/core" # Libre Office Core
loccommit="4c0040b6f1e3137e0d40aab09088c43214db3165" # known to work commit number
getlocourl="https://github.com/LibreOffice/core.git"
pocobase="/opt/poco"
getpocourl="http://pocoproject.org/releases/poco-1.7.7/poco-1.7.7-all.tar.gz" # known-to-work poco version
getpocofile=poco-1.7.7-all.tar.gz
poco="/opt/poco/poco-1.7.7-all"
loo="/opt/online" # LibreOffice Online
getloourl="https://github.com/LibreOffice/online"
loocommit="91666d7cd354ef31344cdd88b57d644820dcd52c" # known-to-work commit number (=SHA1 hash). Ref: https://gist.github.com/m-jowett/0f28bff952737f210574fc3b2efaa01a
cpu=`nproc`


### SHOW INFO MESSAGE AND DO PREREQUISITES ###
#
# Abort and throw message if script isn't invoked as root or sudo.
if [[ `id -u` -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi
clear
apt-get update && apt-get upgrade && apt-get install dialog beep sleep -y 
dialog --backtitle "Information" \
--TITLE "NOTE" \
--msgbox '* First edit the script top section with some global variables to set admin username and password etc and then rerun the script.\n\n* You may also need to manualy uncomment your deb-src main line in /etc/apt/sources.list or you can uncomment a sed line in the script that attempts to do it for you.\n\n* If you have a DNSSec-enabled zonefile with TLSA-records you should add a record for port 9980 because the LibreOffice online daemon runs on that port. \n\n* To get a complete logfile run this script with ./office-online.sh > output.txt.\n\n* Press Ctrl+c twice to abort the script.\n\nTHE INSTALLATION WILL TAKE REALLY VERY LONG TIME, 2-8 HOURS (It depends on the speed of your server), SO BE PATIENT PLEASE!!!\n\nYou may see errors during the installation, just ignore them and let it do the work.' 30 150
clear
# Create user
useradd lool -s /bin/bash && mkdir -p /home/lool && chown lool:lool /home/lool -R
# Make user run sudo without entering password. Needed for running make as lool-user which invokes sudo /sbin/setcap 
echo "lool ALL=NOPASSWD:ALL" >> /etc/sudoers

### 1. DOWNLOAD & COMPILE LIBREOFFICE CORE ###
#
echo "Will now prepare for LibreOffice Core build."
beep
#
# sed -i 's/# deb-src/deb-src/g' $soli && apt-get update
# Update the sources and install build-dependencies.
# The package libkrb5-dev seems to be not included, so we will install it separately.
apt-get build-dep libreoffice && apt-get install libkrb5-dev -y
# Download and install LOC source files.
cd $rootdir && git clone -b master --single-branch $getlocourl $loc
# Enter directory and change to a known-to-compile commit.
cd $loo && git reset --hard $loccommit
# Fix file ownership
chown -R lool:lool $loc
# Build 
echo "Will now start building LibreOffice Core, from commit: "${loccommit}""
echo "The build will run make with -i flag (ignore errors) to ignore a canvas_emfplus unit test which should be safe"
beep && sleep 5
cd $loc && ./autogen.sh --without-help --without-myspell-dicts
cd $loc && ./configure
# Doesn't like root-build so we pass -i by default to ignore errors. Otherwise run sudo -H -u lool bash -c cd $loc && make	       
cd $loc && make build-nocheck -i 
echo "Finished with make, skipping make check"
echo "Finished building LibreOffice Core"
sleep 2
# Double fix file ownership
chown -R lool:lool $loc


### 2. BUILDING LIBREOFFICE ON-LINE PLATFORM ###
## 2.1. BUILDING POCO FROM SOURCE ##
# Section reference: https://github.com/LibreOffice/online/blob/master/wsd/README
#
###
# Install the dependencies required to compile the source. For some reason this also removes the packages: libssl1.0-dev node-gyp nodejs-dev npm.
echo "Will prepare to build poco"
beep && sleep 2
apt-get install openssl g++ libssl-dev -y
# Download the source to /opt/poco
mkdir -p $pocobase
cd $pocobase && wget "$getpocourl"
# Unpack the source files to a poco folder and set file ownership
tar -xvf $getpocofile
chown lool:lool $pocobase -R
# Compile and prefix the POCO libraries to /opt/poco/ according to ref.
echo "Will now start building "$pocofile""
beep && sleep 5
# --prefix according to ref
cd $poco && ./configure --prefix=$pocobase
# Install poco and fix permissions
cd $poco && make install && chown lool:lool $poco -R
echo "Finished building poco"

### 2.2. BUILDING LIBREOFFICE ON-LINE SERVER (LOOL-web-socket-daemon) ###
#
# Section reference: https://github.com/LibreOffice/online/blob/master/wsd/README
# There exist Debian specific packages, but for the sake of easier distro-porting we build this from source.
#
###
echo "Next up LibreOffice Online websocket daemon lool-wsd"
beep && sleep 5
# Download source files to /opt/online 
cd $rootdir && git clone $getloourl
# Enter directory and change to a known-to-compile commit.
cd $loo
git reset --hard $loocommit
# Fix file ownership.
chown lool:lool $loo -R
# Install some dependencies for loolwsd.
apt-get install -y libpng12-0 libcap-dev libtool m4 automake
# Install the required c++ libraries.
apt-get install -y libcppunit-dev libcppunit-doc pkg-config
# Build LOOL info
echo "Will now start building LibreOffice Online from the github repo, commit: "$loocommit""
beep && sleep 5
# automake in autogen.sh needed --add-missing so will run ./autogen.sh manually 
cd $loo && libtoolize && aclocal && autoheader && automake --add-missing && autoreconf #replaces ./autogen.sh
# Paths here vary depending on poco installed from source and poco installed from distro-package, see ref.
cd $loo && ./configure --enable-silent-rules --with-lokit-path=$loc/include --with-lo-path=$loc/instdir --with-max-connections=$maxcon --with-max-documents=$maxdoc --with-poco-includes=$poco/include --with-poco-libs=$poco/lib --enable-debug
# Flag MINIFY=true is helpful for production environments according to loleaflet README file in ref.
cd $loo && make MINIFY=true
echo "Finished building LibreOffice Online Web-Socket Daemon."
echo "Will now do some post-install configuration."
beep && sleep 5
# Double fix file ownerships. Had temporary file permission issues with /run/user/X/ but shouldn't happen again.
chown -R lool:lool {$loc,$loo,$poco}
# Create the directory used for caching tiles as set in configure.ac.
# If you did not pass a prefix changing this when running the configure script for loolwsd, the folder should be /usr/local/var/cache/loolwsd.
mkdir -p /usr/local/var/cache/loolwsd
# Fix file ownership
chown -R lool:lool /usr/local/var/cache/loolwsd
### Post-Install Config - Certificates ###
# loolwsd looks in /etc/loolwsd for the self generated ssl certificates which are actually in ./etc/loolws. This can be fixed in at least 3 ways:
#
# Method 1. Link existing certificates there. Had permissions issue so can't use for now.
#sudo mkdir -p /etc/loolwsd
#ln -s /etc/letsencrypt/live/$mydomain/chain.pem /etc/loolwsd/ca-chain.cert.pem
#ln -s /etc/letsencrypt/live/$mydomain/privkey.pem /etc/loolwsd/key.pem
#ln -s /etc/letsencrypt/live/$mydomain/cert.pem /etc/loolwsd/cert.pemn
#
# Method 2. Generate new keys and sign them. Has drawback of not being signed by trusted authority.
# openssl genrsa -out /etc/loolwsd/key.pem 4096
#openssl req -out /etc/loolwsd/cert.csr -key /etc/loolwsd/key.pem -new -sha256 -nodes -subj "/C=DE/OU=cloud.selfhosted.xyz.com/CN=cloud.selfhosted..xyz/emailAddress=hostmaster@selfhosted.xyz"
#openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/cert.pem
#openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/ca-chain.cert.pem 
#
# Method 3: copy all certs and keys to where you want them and set correct location and permissions on the copy.
# This is because lool user doesn't have access rights to /etc/letsencrypt. Works! :D
mkdir -p $loo/etc/mykeys
cp /etc/letsencrypt/live/$mydomain/* $loo/etc/mykeys # Make cronjob for this?
sed -i "s/\/etc\/loolwsd/$loo\/etc\/mykeys/g" $loo/loolwsd.xml
echo "Using LetsEncrypt keys that was copied from /etc/letsencrypt/live/$mydomain/* to $mydomain/etc/mykeys. Remember to copy and overwrite these certificates with renewd ones and to sudo chown -R lool:lool $loo/etc/mykeys"
# Fix file ownership.
chown -R lool:lool /etc/loolwsd
# loolwsd should now run without SSL errors.
# Should now be able to run loolwsd as an unprivilledged user (not root). For running "manually" see REAL RUN and systemd unit below.
echo "make run will now be issued from "$loo" as user lool. You must kill this process from another terminal" && beep && sleep 5
cd $loo && sudo -u lool bash -c "make run"
# log-file location, default is in /tmp I want /var/log/libreoffice-online
mkdir -p /var/log/nextcloud
chown lool:lool /var/log/nextcloud
# make sed command on $lool/loolwsd.xml replacing log location line.

### 2.3. BUILDING LIBREOFFICE ON-LINE CLIENT (LOLEAFLET) ###
#
# Section reference: https://github.com/LibreOffice/online/blob/master/wsd/README
#
# Note: building loleaflet is not needed right now since we ran make run above
# Also we will use nextcloud to connect to loolwsd.
#
###
#
#echo "Next up, LibreOffice Online Web-Client JavaScript Component - loleaflet."
#echo "Please check the README file found in online/loleaflet as some common build errors are addressed there. This is also linked in the Notes section."
#beep && sleep 5
# Some NODEJS dependencies
# Install npm (provided by node.js package) if not installed already.
#apt-get install nodejs -y
# Install dependencies needed to build loleaflet through npm.
#npm install -g jake
#echo "Check whether npm is at least version 3.0."
#npm -v
# If not upgrade npm.
#npm install -g npm
#npm -v
# Create a symbolic link for node.js as the makefile looks for node.js in /usr/bin/node.
#ln -s /usr/bin/nodejs /usr/bin/node
# Double fix file ownerships.
#chown -R lool:lool {$loc,$loo,$poco}

### REAL RUN OF WSD ###
#
# This is the alternative method of make run above.
#
# If you want to do the 'make run' yourself, you need to set up a minimal chroot system, and directory for the jails. 
#
# Note: there will be forking issues "Failed to fork child processes." unless loolforkit has cap_sys_chroot cap_mknod cap_fowner variables set.
#
# Fix this and you can uncomment the code below to do it this way.
#
###

#SYSTEMPLATE=${loo}/systemplate  # or tweak for your system
#ROOTFORJAILS=${loo}/jails       # or tweak for your system
#MASTER=$loc
#rm -Rf ${SYSTEMPLATE} # clean
# The ${SYSTEMPLATE} is a directory tree set up using the loolwsd-systemplate-setup script here. (It should not exist before running the script.)
#cd $loo && sudo -u lool ./loolwsd-systemplate-setup ${SYSTEMPLATE} ${$MASTER}/instdir # build template
#mkdir -p ${ROOTFORJAILS} # create location for transient jails.
# To see an example, run loolwsd, like:
#echo "Will now testrun ./loolwsd from "$loo" as user lool. This might give process fork issues - try visiting https://localhost:9980/loleaflet/dist/admin/admin.html and see if you get errors" 
#cd $loo && sudo -u lool ./loolwsd --o:sys_template_path="${SYSTEMPLATE}" --o:lo_template_path="${MASTER}"/instdir --o:child_root_path="${ROOTFORJAILS}"
#sleep 2 && lsof -i :9980 && sleep 5

#
# Remove lool from sudoers.
sed -i 's/lool ALL=NOPASSWD:ALL//g' /etc/sudoers

#
# To run it manually.
#cd $loo && sudo -u lool ./loolwsd --o:sys_template_path=/opt/online/systemplate --o:lo_template_path=/opt/core/instdir  --o:child_root_path=/opt/online/jails --o: storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=office1234

#
# Information messages:
echo "To run loolwsd with loleaflet use: ./loolwsd --o:sys_template_path=${SYSTEMPLATE} --o:lo_template_path=${MASTER}/instdir --o:child_root_path=${ROOTFORJAILS} where MASTER is $loc/instdir"
echo "If loloeaflet is installed which it isn't by default you should be able to access files within the browser under the URL - this does not include local files: https://localhost:9980/loleaflet/dist/loleaflet.html?file_path=file:///PATH/TO_DOC&host=wss://localhost:9980"
echo "To access the admin panel go to: https://localhost:9980/loleaflet/dist/admin/admin.html"

#
# Systemd service to run loolwsd with loleaflet at startup (dunno how to catch variables so will use sed below):
cat <<EOT > /lib/systemd/system/loolwsd.service

[Unit]
Description=LibreOffice On-Line WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/loolwsd
ExecStart=/opt/online/loolwsd --o:sys_template_path=/opt/online/systemplate --o:lo_template_path=/opt/core/instdir  --o:child_root_path=/opt/online/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=office1234
User=lool
KillMode=control-group
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOT
#
# Use sed with double quotes to evaluate variables and fix the systemd service file.
sed -i "s/password=office1234/password=$adminpass/g" /lib/systemd/system/loolwsd.service
sed -i "s/username=admin/$adminuser/g" /lib/systemd/system/loolwsd.service
#
# No need to use these really
# sed -i "s/\/opt\/core/$loc/g" /lib/systemd/system/loolwsd.service
# sed -i "s/\/opt\/online/$loo/" /lib/systemd/system/loolwsd.service

#
# Set correct admin username and password in loolwsd configuration file. 
sed - i "s/The\ password\ of\ the\ admin\ console\.\ Must\ be\ set\./$adminpass/g" $loo/loolwsd.xml
sed - i "s/The\ username\ of\ the\ admin\ console\.\ Must\ be\ set\./$adminuser/g" $loo/loolwsd.xml
# TODO set correct domain in loolwsd.xml; something like <host desc="Regex pattern of hostname to allow or deny." allow="true" cloud.mydomain.com

#
# Enable as startup service
echo "Will now enable loolwsd as a startup service"
systemctl daemon-reload && systemctl enable loolwsd.service
#systemctl start loolwsd.service

dialog --backtitle "Information" \
--title "Note" \
--msgbox "You can start loolwsd.service which is the service running LibreOffice Online by using: systemctl {start,stop,status} loolwsd.service.\n\n * Your admin username and password is set in /lib/systemd/system/loolwsd.service and should be set to "$adminuser" and "$adminpass" respectively. Sometimes restarting the server too frequently or over ssh causes issues, it doesn't mean it's a problem with your installation." 20 145
clear
sleep 2
systemctl status loolwsd
echo ""
echo "DONE! Enjoy!!!"
echo ""

exit

# DEPRECATED NOTES

### POCO BUILD FROM SOURCE ###
# Poco build dependencies. Debian package is otherwise libpoco-dev. For guide see:  https://gist.github.com/m-jowett/0f28bff952737f210574fc3b2efaa01a
#apt-get install openssl g++ libssl-dev
#
#mkdir -p /opt/poco
#cd /opt/poco
#wget http://pocoproject.org/releases/poco-1.7.4/poco-1.7.4-all.tar.gz
#tar -xv -C poco -f poco-1.7.4-all.tar.gz
#cd poco/poco-1.7.4-all
#./configure --prefix=/opt/poco
#make install

#SYSTEMPLATE=$(pwd)/systemplate
#ROOTFORJAILS=$(pwd)/jails
#MASTER="/opt/online/bundled"
#MASTER="/opt/karoshi/karoshi_user/core"

#openssl genrsa -out /etc/loolwsd/key.pem 4096
#openssl req -out /etc/loolwsd/cert.csr -key /etc/loolwsd/key.pem -new -sha256 -nodes -subj "/C=DE/OU=onlineoffice-install.com/CN=onlineoffice-install.com/emailAddress=nomail@nodo.com"
#openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/cert.pem
#openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/ca-chain.cert.pem
