#!/bin/bash
htuser=www-data
cd $1
for file in `dir -d *` ; do
  ffmpeg -i $file $file.mp3
  chown $htuser:$htuser $file.mp3 
done
