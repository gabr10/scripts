#!/bin/bash
# foscamrecorder.sh
# ------------
# This script saves the live video from the Foscam IP cameras to a full-quality mp4 file.


# Author: @gabr10
   
# 3.4.2: Cleanup
# 3.4.1: No audio for any but internal, which now uses copy instead of aac (which worked OK)

# #Stops around midnight. systemd timer expected to revive it immediately.




on_die () {
    # kill all children
    echo "foscamhls2021 is DED. Killing children"
    pkill -KILL -P $$
}

trap 'on_die' TERM



name="`/bin/date +%Y-%m-%d_%H%M.%S`"
echo "Running foscamrecorder script at: $name"

# Where the videos will be saved
BP='/var/www/html/cams'
RECORDERPATH="$BP/recordings"
ARCHIVERPATH="$BP/archive"

SRV="192.168.1"
CAM1="$SRV.11:554"
CAM2="$SRV.12:555"
CAM3="$SRV.13:556"
CAM4="$SRV.14:557"

USERPASS="admin:admin"

#HLS List size in seconds. Set to 1800 = 30 minutes of immediate DVR.
SEGMENT_LIST_SIZE=1800

#Set socket TCP I/O timeout in microseconds. 3000000 = 3 seconds
TIMEOUT=3000000

chown -R www-data:www-data "$BP";

# Starts recording on a given camera based on arg #1
runcam () {

   echo "runcam for cam: $1"
   cam="$1"

    THISDIR="$RECORDERPATH/$cam";
    REQUESTURL=""
    
    #for this cam, remove previous playlists, this will make stuff dirty otherwise
    rm $THISDIR/*.m3u8

    # The following section is done in individual IF conditions for each camera. If they all share the same
    # attributes, a for loop would be much better.

    # In this case, cam01 supports audio OOTB. The rest do not.

    if [ "$cam" = "cam01" ]; then
        REQUESTURL="rtsp://$USERPASS@$CAM1/videoMain"

        /usr/local/bin/ffmpeg -loglevel level+trace -rtsp_transport tcp \
        -timeout $TIMEOUT \
        -i "$REQUESTURL" \
        -c:v copy \
        -c:a copy \
        -f ssegment \
        -segment_time 2 \
        -segment_format mpegts \
        -segment_list "$THISDIR/$name.m3u8" \
        -segment_list_size $SEGMENT_LIST_SIZE \
        -segment_list_flags live \
        -segment_list_type m3u8 \
        "$THISDIR/$name-%08d.ts" > /var/log/$cam-$name-ffmpeglog.txt 2>&1 & echo $! > /run/$cam.pid
        echo $!

    fi
    if [ "$cam" = "cam02" ]; then
        REQUESTURL="rtsp://$USERPASS@$CAM2/videoMain"

        /usr/local/bin/ffmpeg -loglevel level+trace -rtsp_transport tcp \
        -timeout $TIMEOUT \
        -i "$REQUESTURL" \
        -c:v copy \
        -map 0:0 \
        -f ssegment \
        -segment_time 2 \
        -segment_format mpegts \
        -segment_list "$THISDIR/$name.m3u8" \
        -segment_list_size $SEGMENT_LIST_SIZE \
        -segment_list_flags live \
        -segment_list_type m3u8 \
        "$THISDIR/$name-%08d.ts" > /var/log/$cam-$name-ffmpeglog.txt 2>&1 & echo $! > /run/$cam.pid
        echo $!

    fi
    if [ "$cam" = "cam03" ]; then
        REQUESTURL="rtsp://$USERPASS@$CAM3/videoMain"

        /usr/local/bin/ffmpeg -loglevel level+trace -rtsp_transport tcp \
        -timeout $TIMEOUT \
        -i "$REQUESTURL" \
        -c:v copy \
        -map 0:0 \
        -f ssegment \
        -segment_time 2 \
        -segment_format mpegts \
        -segment_list "$THISDIR/$name.m3u8" \
        -segment_list_size $SEGMENT_LIST_SIZE \
        -segment_list_flags live \
        -segment_list_type m3u8 \
        "$THISDIR/$name-%08d.ts" > /var/log/$cam-$name-ffmpeglog.txt 2>&1 & echo $! > /run/$cam.pid
        echo $!

    fi
    
    
    if [ "$cam" = "cam04" ]; then
        REQUESTURL="rtsp://$USERPASS@$CAM4/videoMain"
        #echo "Starting ffmpeg for cam:$cam at $REQUESTURL"

        /usr/local/bin/ffmpeg -loglevel level+trace -rtsp_transport tcp \
        -timeout $TIMEOUT \
        -i "$REQUESTURL" \
        -c:v copy \
        -map 0:0 \
        -f ssegment \
        -segment_time 2 \
        -segment_format mpegts \
        -segment_list "$THISDIR/$name.m3u8" \
        -segment_list_size $SEGMENT_LIST_SIZE \
        -segment_list_flags live \
        -segment_list_type m3u8 \
        "$THISDIR/$name-%08d.ts" > /var/log/$cam-$name-ffmpeglog.txt 2>&1 & echo $! > /run/$cam.pid
        echo $!

    fi

    echo "Should have started ffmpeg for $cam..."
    ps -ef | grep ffmpeg | grep -v grep
   
}



# This function deletes any files older than X so that we don't overwhelm storage capacity.
for cam in cam01 cam02 cam03 cam04; do
    
    #echo "Deleting files older than 4 days on both recordings and archive..."
    #find /cams/video/$cam/ -mmin +5760 -exec rm -rf {} \;
    #28h
    #echo "Removing files older than 7 days";
    #cd $RECORDERPATH/$cam;
    #find ./*/, -mmin +10080 | xargs rm -rf
    echo "Removing files older than 4 days";
    cd $ARCHIVERPATH/$cam/;
    find $ARCHIVERPATH/$cam/ -mmin +5760 | xargs rm -rf

    echo "Removing SEGMENTS older than 2 hours";
    cd $RECORDERPATH/$cam;
    find ./*.ts -mmin +120 | xargs rm -rf
    echo "Removing m3u8s older than 10 min. We dont need them.";
    find ./*.m3u8 -mmin +10 | xargs rm -rf
    echo "calling runcam for cam $cam"
    runcam $cam
    
done

finish="`/bin/date +%Y-%m-%d_%H%M.%S`"

#UNCOMMENT THESE TWO AFTER TESTING MANUALLY
echo "foscamrecorder completed at: $finish, running stream creator script"


# Log runs to evaluate stability

LOGFILE="/tmp/autotest_run_count.txt"

trap "echo manual abort; exit 1"  1 2 3 15

RUNS=0

#Loop to evaluate camera liveness and restart if they die.
while [ 1 ] 
do
    RUNS=$((RUNS+1))
    HOUR="$(date +'%H')"
    MIN="$(date +'%M')"
    if [ $HOUR -eq "00" -a $MIN -eq "00" ] ; then
        echo "GABRIO: Hit the reset button after $RUNS runs!!"

        # We use a systemctl service to start this script whenever it stops running.
        systemctl stop hls2021.service
        break
        # exit 0
    else
        echo "Confirming FFMPEG PIDs are still there..."


        for cam in cam01 cam02 cam03 cam04; do
            input="/run/$cam.pid"
            while IFS= read -r line
            do
              echo "ffmpeg pid $cam: $line"
              RES=$(ps -ef |  awk '{print $1" "$2" "$3" "$8" "$16}'| grep $line |  grep -v grep)
              if [[ "$RES" != *"ffmpeg"* ]]; then
                    echo "GABRIO: $cam PID doesnt exist. Restarting it after $RUNS runs!!!!"
                    runcam "$cam"
                break
              fi
            done < "$input"
        done


        echo "Healthcheck runs: $RUNS , since the script started at $name, waiting now. Last run at $HOUR:$MIN " > $LOGFILE
        sleep 60

    fi

done


