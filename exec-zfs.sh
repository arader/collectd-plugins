#!/bin/sh

# A collectd 'exec' script used to get zfs dataset statistics

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -f)}"
INTERVAL="${COLLECTD_INTERVAL:-300}"

LIST_POOLS_CMD="${LIST_POOLS_CMD:-zpool list -H -o name}"
POOL_STATUS_CMD="${POOL_STATUS_CMD:-zpool status \$1}"

LIST_DATASETS_CMD="${LIST_DATASETS_CMD:-zfs list -Hp -o name,usedds,usedchild,usedsnap,usedrefreserv,avail}" 

TIME_CMD="${TIME_CMD:-date +%s}"

if [ "$INTERVAL" -lt 300 ]
then
    INTERVAL=300
fi

arg()
{
    shift $1
    echo $2
}

process_pools()
{
    $LIST_POOLS_CMD | while read line
    do
        process_pool $line
    done
}

process_pool()
{
    local parsing='scan'

    eval $POOL_STATUS_CMD | while read line
    do
        case $parsing in
            scan)
                echo $line | grep -E '^scan: ' > /dev/null 2>&1
        
                if [ $? == 0 ]
                then
                    process_pool_scrub_status $1 "$line"

                    parsing='status_header'
                fi
                ;;
            status_header)
                echo $line | grep -E '^NAME[	 ]+STATE[	 ]+READ[	 ]+WRITE[	 ]+CKSUM$' > /dev/null 2>&1

                if [ $? == 0 ]
                then
                    parsing='status_info'
                fi
                ;;
            status_info)
                if [ "$line" == "" ]
                then
                    parsing=done
                    break
                fi

                process_pool_member_status $1 "$line"

                ;;
            *)
                ;;
        esac
    done
}

process_pool_scrub_status()
{
    #TODO handle running scrub

    local repaired="U"
    local duration="U"
    local errors="U"

    if [ "$2" != "scan: none requested" ]
    then
        local scrub_status=$(echo "$2" | sed -E 's/[^0-9]+ ([0-9]+) in ([0-9]+h[0-9]+m) with ([0-9]+) errors on (.*)/\1 \2 \3 \4/')
        repaired=$(arg 0 $scrub_status)
        duration=$(arg 1 $scrub_status | sed -E 's/^([0-9]+)h([0-9]+)m$/\1*3600 + \2*60/' | bc)
        errors=$(arg 2 $scrub_status)
    fi

    echo "PUTVAL $HOSTNAME/zpool-$1/count-scrub-repaired interval=$INTERVAL $TIME:$repaired"
    echo "PUTVAL $HOSTNAME/zpool-$1/duration-scrub interval=$INTERVAL $TIME:$duration"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-scrub-errors interval=$INTERVAL $TIME:$errors"
}

process_pool_member_status()
{
    local device=$(arg 0 $2 | sed -e 's|^/||' -e 's|/|.|')
    local read_count=$(arg 2 $2)
    local write_count=$(arg 3 $2)
    local cksum_count=$(arg 4 $2)

    echo "PUTVAL $HOSTNAME/zpool-$1/count-read-errors.$device interval=$INTERVAL $TIME:$read_count"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-write-errors.$device interval=$INTERVAL $TIME:$write_count"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-cksum-errors.$device interval=$INTERVAL $TIME:$cksum_count"
}

process_datasets()
{
    $LIST_DATASETS_CMD | while read line
    do
        process_dataset $line
    done
}

process_dataset()
{
    local dataset=$(echo $1 | sed 's|/|.|g')

    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedds interval=$INTERVAL $TIME:$2"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedchild interval=$INTERVAL $TIME:$3"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedsnap interval=$INTERVAL $TIME:$4"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-usedrefreserv interval=$INTERVAL $TIME:$5"
    echo "PUTVAL $HOSTNAME/zfs-$dataset/bytes-avail interval=$INTERVAL $TIME:$6"
}

while true
do
    TIME=$($TIME_CMD)

    process_pools

    process_datasets

    if [ -z "$RUN_ONCE" ]
    then
        sleep "$INTERVAL"
    else
        exit
    fi
done
