#!/bin/sh

# A collectd 'exec' script used to get dhcpd lease info
# from dhcpd-pools

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -f)}"
INTERVAL="${COLLECTD_INTERVAL:-10}"

PATH=$PATH:/usr/local/bin

$(which dhcpd-pools >/dev/null 2>&1)
if [ $? != 0 ]; then
    echo "Missing dhcpd-pools command" >&2
    exit 1
fi

$(which jq >/dev/null 2>&1)
if [ $? != 0 ]; then
    echo "Missing jq command" >&2
    exit 1
fi

while sleep "$INTERVAL"
do
    time="$(date +%s)"
    dhcpd-pools -f j | jq --arg HOST $HOSTNAME --arg INTERVAL $INTERVAL --arg TIME $time -r '.subnets[] |
"PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/count-defined interval=\($INTERVAL) \($TIME):\(.defined)
PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/count-used interval=\($INTERVAL) \($TIME):\(.used)
PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/count-touched interval=\($INTERVAL) \($TIME):\(.touched)
PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/count-free interval=\($INTERVAL) \($TIME):\(.free)
PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/percent-used interval=\($INTERVAL) \($TIME):\(.percent)
PUTVAL \($HOST)/dhcpd-\(.range|gsub("\\s+";"")|gsub("-";"_"))/percent-touched interval=\($INTERVAL) \($TIME):\(.touch_percent)"'

done
