#!/bin/sh

export COLLECTD_HOSTNAME="exec-tests.example.org"
export RUN_ONCE="yes"
export TIME_CMD="echo 999999"

# First run pool status tests
export LIST_POOLS_CMD="echo test"
export LIST_DATASETS_CMD=" "

ec=0

find ./tests -iname '*.status' | while read file
do
    export POOL_STATUS_CMD="cat \"$file\""
    name="$(basename -s .status $file)"

    if [ ! -f "$file.expected" ]
    then
        printf '\033[0;31mFAIL\033[0m\033[0;37m:\033[0m '
        echo "$name doesn't have expected output file" >&2
        ec=1
        continue
    fi

    ./exec-zfs.sh | diff - "$file.expected"

    if [ $? != 0 ]
    then
        ec=1
    else
        printf '\033[0;32mPASS\033[0m\033[0;37m:\033[0m '
        echo "$name"
    fi
done

exit $ec
