#!/bin/bash
# archiver.sh
#
# ------------
# Call via cron job or systemd service/timer combination to automatically archive
# videos from foscamrecorder.sh into a single video per hour, with increased framerate
# ------------
#
# Author: @gabr10


# 1.0

echo "Starting archiver..."

dat="`TZ=America/Costa_Rica /bin/date +%Y-%m-%d_`"
h="`TZ=America/Costa_Rica /bin/date +%H`"
m=-1

# Where the videos are saved. Set this path to your local videos directory.

RECpath='/path/to/surveillance/folder'

finalhr=$(( 10#$h + $m ))
finalhr=$(printf %02d $finalhr)
echo "$h + $m = $finalhr"
NAME=$dat$finalhr;

#account for 00
if [ "$h" = "00" ]; then
    finalhr=23
fi


for cam in cam01 cam02 cam03; do
    echo "Archiving last hour for full date: $NAME"
    cd $RECpath/$cam/
    for f in ./$NAME*.mp4; 
    do echo "file '$f'" >> $NAME.txt; 
    done;
    ffmpeg -f concat -safe 0 -i $NAME.txt -c copy output.mp4;
    ffmpeg -y -i output.mp4 -c copy -f h264 $NAME.h264;
    ffmpeg -y -r 72 -i $NAME.h264 -c copy $cam-$NAME.mp4;
    rm $NAME.h264;
    rm output.mp4;
    for f in ./$NAME*.mp4; 
    do rm -rf $f; 
    done
done