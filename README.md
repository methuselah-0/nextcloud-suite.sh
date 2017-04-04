Eventually this repository will cover a full suite installation of Nextcloud to hopefully become an automated install of a proper alternative to Office365 & Dropbox in one. For now it's only usable for installing LibreOffice Online with the install.sh file.

# officeonline-install.sh

Script to install Office Online on Debian Testing (might work on Ubuntu 16.04 as well), and hopefully it will eventually have a full script for an entire nextcloud setup with good configurations.

## License info
Originally Written by: Subhi H.<br>
This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

## This Fork Info
My additions and changes are also GPLv3 license.

This is my first ever written bash-script. Use at your own risk.

Reasons:
  - Libreoffice-Online builds were not working so I tried to make this fork more failsafe by having source versions set to known-to-work commits.
  - I also wanted a more commented version to better understand the installation process.

Tested to work on Debian Testing with nginx, mariadb, and php7 with the following sources and commit versions:
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

## Prerequisites
  - A running NextCloud server (i.e. won't setup nginx configuration for you).
  - Valid letsencrypt certificates for your domain in /etc/letsencrypt/mydomain.tld/*

## Installation
1. Clone/Download the files:
  git clone https://github.com/methuselah-0/nextcloud-suite.sh
2. Open the install.sh file and edit "mydomain", libreoffice-online admin password, location of your existing letsencrypt certificates, maximum document connections etc. Then:
  cd nextcloud-suite && emacs -nw install.sh
5. Make it executable:
  sudo chmod +x install.sh
5. Run the script
  sudo ./install.sh
6. Go to apps section in your Nextcloud and enable the Collabora Online app. Then to Admin->Admin->Collabora Online and enter your url and port number. (e.g. if you visit your cloud instance at https://nextcloud.mydomain.com you would enter https://nextcloud.mydomain.com:9980 )
Read the first run info dialog box and then the building process should mostly run on it's own.

You might need to go to /opt/online/loolwsd.xml and put a line like this there next to the other similar ones.
<host desc="Regex pattern of hostname to allow or deny." allow="true" cloud.mydomain.com


THE INSTALLATION WILL TAKE REALLY VERY LONG TIME SO BE PATIENT PLEASE!!! You may eventually see errors during the installation, just ignore them."
