#!/bin/sh

# A collectd 'exec' script used to get zfs dataset statistics

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -f)}"
INTERVAL="${COLLECTD_INTERVAL:-10}"

print_dataset()
{
    dataset=$(echo $2 | sed 's|/|.|g')

    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedds interval=$INTERVAL $1:$3"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedchild interval=$INTERVAL $1:$4"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedsnap interval=$INTERVAL $1:$5"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedrefreserv interval=$INTERVAL $1:$6"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-avail interval=$INTERVAL $1:$7"
}

while sleep "$INTERVAL"
do
    time="$(date +%s)"

    zfs list -Hp -o name,usedds,usedchild,usedsnap,usedrefreserv,avail | while read line
    do
        print_dataset $time $line
    done
done
