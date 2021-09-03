#!/bin/sh

# A collectd 'exec' script used to get dns server stats from unbound

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname)}"
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

CTRLBIN=$(which unbound-control 2>/dev/null)

while sleep "$INTERVAL"
do
    time=$(date +%s)

    stats=$($CTRLBIN stats 2>/dev/null)

    # run through histogram values
    for histogram in $(echo "$stats" | grep -i histogram.)
    do
        bound=$(echo "$histogram" | sed -e 's/.*to.\([^=]*\).*/\1/')
        value=$(echo "$histogram" | sed -e 's/[^=]*=\(.*\)/\1/')
        echo "PUTVAL $HOSTNAME/unbound-histogram/count-$bound interval=$INTERVAL $time:${value:-U}"
    done

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

        echo "PUTVAL $HOSTNAME/unbound-counters/$type-$name interval=$INTERVAL $time:${value:-U}"
    done
done
