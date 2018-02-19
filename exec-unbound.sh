#!/bin/sh

# A collectd 'exec' script used to get dns server stats from unbound

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -f)}"
INTERVAL="${COLLECTD_INTERVAL:-10}"

COUNTERS="total.num.queries \
    total.num.cachehits \
    total.num.cachemiss \
    total.num.prefetch \
    total.num.recursivereplies \
    total.requestlist.avg \
    total.requestlist.max \
    total.requestlist.overwritten \
    total.requestlist.exceeded \
    total.recursion.time.avg \
    total.recursion.time.median \
    total.tcpusage \
    mem.cache.rrset \
    mem.cache.message \
    num.answer.secure \
    num.answer.bogus \
    unwanted.queries \
    unwanted.replies \
    msg.cache.count \
    rrset.cache.count"

while sleep "$INTERVAL"
do
    time=$(date +%s)

    stats=$(/usr/local/sbin/unbound-control stats 2>/dev/null)

    for counter in $COUNTERS
    do
        iscache=$(echo $counter | grep -i cache)
        type="count"

        if [ ! -z "$iscache" ]
        then
            type="gauge"
        fi

        name=$(echo $counter | sed 's/\./-/g')
        value=$(echo "$stats" | sed -e "s/^$counter=\([^ ]*\)$/\1/" -e 'tx' -e 'd' -e ':x')

        echo "PUTVAL $HOSTNAME/exec-unbound/$type-$name interval=$INTERVAL $time:${value:-U}"
    done
done
