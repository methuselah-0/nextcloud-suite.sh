#!/bin/bash
htuser="www-data"
htgroup="www-data"

echo "dollar 1 is $1"
cd "$1"
for ext in 'flac' 'wav' 'ogg' 'wma' 'aac' 'swa' ; do
    echo "Now looking for files to convert from $ext to .mp3"
    find . -type f -iname "*$ext" -print0 | while read -r -d '' file ; do
	outfile="${file%$ext}mp3"
	echo "Pwd is `pwd`"
	echo "Outfile is $outfile"	
	echo "file is $file"
	ffmpeg -i "$file" "$outfile" -y -vsync 2 </dev/null
	chown $htuser:$htgroup "$outfile"
    done
done
echo "To copy these files to your Nextcloud server with maintained file permissions issue something like: rsync -Aaog -e 'ssh -p 443 -o VerifyHostKeyDNS=yes' --info=progress --no-i-r $1 root@host-ip:/var/www/selfhosted.xyz/nextcloud/data/myname/files/Music"
echo "You might need to edit the ID3 tag on your files to have them be identified by Nextcloud music audio player. Easytag does this by running easytag musicdir and then applying the identified changes from the interface."
cd -    

#    if [ -d "$dir" ]; then
#	echo "I could now have recursed into $obj"
#	#	    (recursive-audiofiles-to-mp3 $obj)
#	exit 0
#	fi


# example: for f in $(dir ./ | egrep "*.wav|*.ogg|*.wma|*.swa|*.flac") ; do
# Fix a file-path: sed 's/\ /\\ /g'
# Get correct file path immediately ./dir
# example: fpath=`realpath $file | sed 's/\ /\\ /g'`
# dir $1 -1
#basedir="$(realpath "$1" | sed 's/\ /\\ /g')"
#cd "$1" && for file in $(dir ./ | egrep "*.wav|*.ogg|*.wma|*.swa|*.flac|*/") ; do
#cd "$1" && for file in $(dir ./ -1) ; do
#shopt -s globstar nullglob dotglob
