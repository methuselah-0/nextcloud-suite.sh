# Audio music player - 3rd party app
# command line usage of the app, ref: https://github.com/Rello/audioplayer/wiki/OCC-Command-Line
#Add to config/mimetypemapping.json unless they already exist (which they do by default in nc 11.02.
#"mp3": ["audio/mpeg"],
#"ogg": ["audio/ogg"],
#"opus": ["audio/ogg"],
#"wav": ["audio/wav"],
#"m4a": ["audio/mp4"],
#"m4b": ["audio/mp4"],

# Update MIME-TYPES. Below from https://github.com/rello/audioplayer/wiki/audio-files-and-mime-types
# "You have to update the table *PREFIX*mimetypes with the newly added MIME types and correct the file mappings in the table *PREFIX*filecache with occ command ./occ maintenance:mimetype:update-db --repair-filecache as well as the core/js/mimetypelist.js with command ./occ maintenance:mimetype:update-js.

# sudo -u $htuser php $nc/occ -vvvv maintenance:mimetype:update-db --repair-filecache
# sudo -u $htuser php $nc/occ -v maintenance:mimetype:update-js
