# Etherpad-Lite install see wiki.selfhosted.xyz for known-to-work procedure.

# Ownpad
# occ app install command
# cp $nc/resources/config/mimetypemapping.dist.json config/mimetypemapping.json
# add these sed replace _comment5 with itself and two more lines.
# "pad": ["application/x-ownpad"],
# "calc": ["application/x-ownpad"],
# chown $htuser:$htgroup $nc/config/mimetypemapping.json
#sudo -u www-data php /var/www/mydomain.tld/nextcloud/occ -vvvv maintenance:mimetype:update-db --repair-filecache
#sudo -u www-data php /var/www/mydomain.tld/nextcloud/occ -v maintenance:mimetype:update-js
# Double-scan files
# sudo -u www-data php occ files:scan --all

