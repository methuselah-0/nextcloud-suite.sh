set -e

installDependencies(){
    apt-get install gcc make python-zbar libltdl-dev libsqlite3-dev libunistring-dev libopus-dev libpulse-dev openssl libglpk-dev texlive libidn11-dev libmysqlclient-dev libpq-dev libarchive-dev libbz2-dev libflac-dev libgif-dev libglib2.0-dev libgtk-3-dev libmpeg2-4-dev libtidy-dev libvorbis-dev libogg-dev zlib1g-dev g++ gettext libgsf-1-dev libunbound-dev libqrencode-dev libgladeui-dev nasm texlive-latex-extra libunique-3.0-dev gawk miniupnpc libfuse-dev libbluetooth-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good libgstreamer-plugins-base1.0-dev nettle-dev libextractor-dev libgcrypt20-dev libmicrohttpd-dev sqlite3 git automake autoconf
    wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.3/gnutls-3.3.12.tar.xz
    wget https://gnunet.org/sites/default/files/gnurl-7.40.0.tar.bz2
    tar xvf gnutls-3.3.12.tar.xz
    tar xvf gnurl-7.40.0.tar.bz2
    cd gnutls-3.3.12 ; ./configure ; make ; make install ; cd ..
    cd gnurl-7.40.0
    ./configure --enable-ipv6 --with-gnutls=/usr/local --without-libssh2 --without-libmetalink --without-winidn --without-librtmp --without-nghttp2 --without-nss --without-cyassl --without-polarssl --without-ssl --without-winssl --without-darwinssl --disable-sspi --disable-ntlm-wb --disable-ldap --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-file --disable-ftp --disable-smb
    make ; make install; cd ..
}
addUser(){
    adduser --system --home /var/lib/gnunet --group --disabled-password gnunet
    addgroup --system gnunetdns
}

install(){
    git clone https://gnunet.org/git/gnunet.git/
    cd gnunet
    ./bootstrap
    ./configure --with-sudo=sudo --with-nssdir=/lib
    make
    make install
    # You may need to update your ld.so cache to include files installed in /usr/local/lib:    
    ldconfig
}

createConf(){
cat <<EOF > /etc/gnunet.conf
[arm]
SYSTEM_ONLY = YES
USER_ONLY = NO
EOF
}
userAdd(){
    read -p "Your username? " ;
    local username=$REPLY && continue
    if [[ $REPLY = y ]] ; then addUser ; fi
    adduser $username gnunet  
cat <<EOF > /home/"$username"/.config/gnunet.conf
[arm]
SYSTEM_ONLY = NO
USER_ONLY = YES
EOF
    echo "Added user: "$username" to group gnunet and created configuration file in /home/"$username"/.config/gnunet.conf."
    echo "You have to logout and login again for this user to use gnunet."
}

makeStartScript(){
cat <<EOF > /var/lib/gnunet/gnunet-start.sh
#!/bin/bash
declare -i COUNTER=0
TIMER=480 # seconds
while [ $COUNTER -lt 1000 ] ; do
    gnunet-arm -c /etc/gnunet.conf -s
        echo "This is restart number: ${COUNTER}"
        echo "The restart timer is set to: $TIMER"
        sleep $TIMER
        COUNTER+=1
        if pgrep -f gnunet-service-arm ; then gnunet-arm -e ; fi
        sleep 1
        if pgrep -f gnunet-service-arm ; then killall gnunet-service-arm ; fi
done
EOF
}

main(){
    if [[ `id -u` -ne 0 ]] ; then echo 'Please run me as root or "sudo ./install-devuan.sh"' ; exit 1 ; fi
    installDependencies
    install
    createConf
    read -p "Right now only the users gnunet and root can use gnunet. Would you like to let a regular user use gnunet? (recommended) (y/n) "
    if [[ $REPLY = y ]] ; then addUser ; fi
    makeStartScript
    echo "You can start and stop your GNUnet with:"
    echo "**Start**"
    echo "  su -s /bin/bash - gnunet"
    echo "  gnunet-arm -c /etc/gnunet.conf -s &"
    echo "**Stop**"
    echo "  gnunet-arm -e"
    echo "Note, that if your gnunet stops working just try to restart it."
}
main
