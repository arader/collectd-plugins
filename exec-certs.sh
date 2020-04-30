#!/bin/sh

# A collectd 'exec' script used to get the number of seconds until certs expire

HOSTNAME="${COLLECTD_HOSTNAME:-$(hostname -f)}"
INTERVAL="${COLLECTD_INTERVAL:-10}"

PATH=$PATH:/usr/local/bin

$(which openssl >/dev/null 2>&1)
if [ $? != 0 ]; then
    echo "Missing openssl command" >&2
    exit 1
fi

HOSTS=$@

if [ "$INTERVAL" -lt 60 ]
then
    INTERVAL=60
fi

while sleep "$INTERVAL"
do
    for host in $HOSTS
    do
        result=U
        time=$(date +%s)
        notAfterDate=$(echo | openssl s_client -connect "$host" 2> /dev/null | openssl x509 -noout -enddate 2> /dev/null | cut -d = -f 2)

        if [ $? == 0 ]
        then
            notAfterEpoch=$(date -jf "%b %e %H:%M:%S %Y %Z" "$notAfterDate" +%s 2> /dev/null)
    
            if [ $? == 0 ]
            then
                ttl=$(echo "$notAfterEpoch - $(date +%s)" | bc 2> /dev/null)
    
                if [ $? == 0 ]
                then
                    result=$ttl
                fi
            fi
        fi

        echo "PUTVAL $HOSTNAME/certs-$host/timeleft-ttl interval=$INTERVAL $time:$result"
    done
done
