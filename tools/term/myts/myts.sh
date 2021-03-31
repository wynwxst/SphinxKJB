#!/bin/sh
if [ $1 == kill ] ; then 
 killall myts 
 usleep 500000
 killall myts 
 exit 0
fi

cd /mnt/us/myts/
if ps aux | grep -q [.]/myts$ ; then
 true
else
 mknod /var/tmp/myts.special p
 ./myts &
 usleep 500000
fi

if echo $1 | grep -q [0-9] ; then
 echo -e A$1\0 > /var/tmp/myts.special
 echo send 0 > /proc/keypad 
fi
 
