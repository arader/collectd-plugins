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

argv()
{
    shift $1
    echo $2
}

argc()
{
    local count=$1
    shift

    [ $count == $# ]
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
        state_DEGRADED=${state_DEGRADED:-0}
        state_FAULTED=${state_FAULTED:-0}
        state_OFFLINE=${state_OFFLINE:-0}
        state_ONLINE=${state_ONLINE:-0}
        state_UNAVAIL=${state_UNAVAIL:-0}

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
                    parsing=complete
                    continue
                fi

                process_pool_member_status $1 "$line"

                ;;
            complete)
                process_pool_states $1
                ;;
            *)
                ;;
        esac
    done
}

process_pool_scrub_status()
{
    local repaired="U"
    local duration="U"
    local errors="U"

    local scrub_status=$(echo "$2" | sed -E -e 's/[^0-9]+([0-9]+)[^0-9]+([0-9]+h[0-9]+m)[^0-9]+([0-9]+).*/\1 \2 \3/' -e 'tx' -e 'd' -e ':x')

    argc 3 $scrub_status

    if [ $? == 0 ]
    then
        repaired=$(argv 0 $scrub_status)
        duration=$(argv 1 $scrub_status | sed -E 's/^([0-9]+)h([0-9]+)m$/\1*3600 + \2*60/' | bc)
        errors=$(argv 2 $scrub_status)
    fi

    echo "PUTVAL $HOSTNAME/zpool-$1/count-scrub-repaired interval=$INTERVAL $TIME:$repaired"
    echo "PUTVAL $HOSTNAME/zpool-$1/duration-scrub interval=$INTERVAL $TIME:$duration"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-scrub-errors interval=$INTERVAL $TIME:$errors"
}

process_pool_member_status()
{
    [ $# == 2 ] || return
    [ ! -z $1 ] || return 

    local name=""

    argc 7 $2 && name=$(argv 6 $2)
    argc 5 $2 && name=$(argv 0 $2)

    [ ! -z $name ] || return

    local device=$(echo $name | sed -e 's|^/||' -e 's|/|.|')
    local state=$(argv 1 $2)
    local read_count=$(argv 2 $2)
    local write_count=$(argv 3 $2)
    local cksum_count=$(argv 4 $2)

    echo "PUTVAL $HOSTNAME/zpool-$1/count-read-errors.$device interval=$INTERVAL $TIME:$read_count"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-write-errors.$device interval=$INTERVAL $TIME:$write_count"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-cksum-errors.$device interval=$INTERVAL $TIME:$cksum_count"

    local count=$(eval "echo \$state_$state + 1" | bc)
    eval "state_$state=$count"
}

process_pool_states()
{
    echo "PUTVAL $HOSTNAME/zpool-$1/count-degraded-state interval=$INTERVAL $TIME:$state_DEGRADED"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-faulted-state interval=$INTERVAL $TIME:$state_FAULTED"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-offline-state interval=$INTERVAL $TIME:$state_OFFLINE"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-online-state interval=$INTERVAL $TIME:$state_ONLINE"
    echo "PUTVAL $HOSTNAME/zpool-$1/count-unavail-state interval=$INTERVAL $TIME:$state_UNAVAIL"
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
        exit 0
    fi
done
