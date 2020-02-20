
## Project Overview
Inspired by projects such as Freedombone, Freedombox, Enigmabox, and email-suite projects such as Mailcow.

A lot of updates to come. Recent update is still old updates from months back.

The goal is to write scripts that autoconfigures a "Net- mesh- and host-box" with the following:
  * Host
    * OS: Devuan for now, but might be Hyperbola later or even PragmaOS some day.
    * network-interfaces: cjdns, gnunet, VPN with public ip. (including mesh auto-peering)
    * firewall: iptables, ipset.
    * DNS: BIND9 with DNSSec and automatic renewal of TLSA, SSHFP and OpenPGP records.
    * rev-proxy: nginx forwarding incoming requests to the virtual machines and listening on all correct network interfaces.
  * Guest-VM 1: Nextcloud suite
    * on a Debian system with: LibreOffice Online, Etherpad-lite, SpreedME (coturn turn-server)
    * or later on either Hyperbola, Devuan or GuixSD.
  * Guest-VM 2: full email stack
    * either on a GuixSD system with OpenSMTPD, Dovecot, clamav, spamassasin.
    * or one of Devuan and Hyperbola using Postfix, Dovecot, spamassasin, clamav.     
  * Guest-VM 3: Dokuwiki
  * Guest-VM 4: Opencart webstore
Ultimately, I would run everything on GuixSD and do this whole project by writing system declarations in Guile.
## Project Progress
So far the following works:
  * Letsencrypt, TLSA renew scripts for a BIND9 zonefile.
  * iptables and ipset update and configure scripts.
  * LibreOffice Online - probably still works, but with an outdate version.
  * debootstrap-devuan.sh
  * gnunet-devuan.sh
The rest is quite easy to make working I believe since Nextcloud, Dokuwiki and Opencart are really quite easy to install. The hard part is to make sure it all gets done smoothly in one run; e.g. debootstrap-devuan.sh is far from hands-off.

## libreoffice-install.sh
The libreoffice-install.sh was tested to work on Debian Testing with Nextcloud running with nginx, mariadb, and php7 with the following sources and commit versions:
  - LibreOffice Core commit=4c0040b6f1e3137e0d40aab09088c43214db3165 url=https://github.com/LibreOffice/core.git
  - Poco=poco-1.7.7-all.tar.gz url: http://pocoproject.org/releases/poco-1.7.7/poco-1.7.7-all.tar.gz
  - LibreOffice Online=91666d7cd354ef31344cdd88b57d644820dcd52c url=https://github.com/LibreOffice/online

It will install
  - LibreOffice Core in /opt/core
  - Poco in /opt/poco
  - LibreOffice Online in /opt/online
The LibreOffice Online web-socket daemon (loolwsd) will run on localhost:9980 which you can connect to from Nextcloud.

You can manage your service with systemctl start/stop/status loolwsd.service.

Enjoy!!!

### Prerequisites
  - A running NextCloud server (i.e. won't setup nginx configuration for you).
  - Valid letsencrypt certificates for your domain in /etc/letsencrypt/mydomain.tld/*

### Installation
After running ./libreoffice-online.sh you need to go to apps section in your Nextcloud admin page and enable the Collabora Online app. Then to Admin->Admin->Collabora Online and enter your url and port number. If you visit your cloud instance at https://nextcloud.mydomain.com you would enter https://nextcloud.mydomain.com:9980

Also, read the first run info dialog box and then the building process should mostly run on it's own.

You might need to go to /opt/online/loolwsd.xml and put a line like this there next to the other similar ones.
<host desc="Regex pattern of hostname to allow or deny." allow="true" cloud.mydomain.com

THE INSTALLATION WILL TAKE REALLY VERY LONG TIME SO BE PATIENT PLEASE!!! You may eventually see errors during the installation, just ignore them."
