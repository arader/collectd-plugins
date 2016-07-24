#!/bin/sh

export COLLECTD_HOSTNAME="exec-tests.example.org"
export RUN_ONCE="yes"
export TIME_CMD="echo 999999"

# First run pool status tests
export LIST_POOLS_CMD="echo test"
export LIST_DATASETS_CMD=" "

pass_total=0
fail_total=0

green()
{
    printf '\033[0;32m%s\033[0m' "$@"
}

red()
{
    printf '\033[0;31m%s\033[0m' "$@"
}

white()
{
    printf '\033[0;37m%s\033[0m' "$@"
}

pass()
{
    green "PASS"
    white ": "
    echo $@

    pass_total=$(echo "$pass_total + 1" | bc)
}

fail()
{
    red "FAIL"
    white ": "
    echo $@

    fail_total=$(echo "$fail_total + 1" | bc)
}

tests=$(find ./tests/exec-zfs -iname '*.status')

for file in $tests
do
    export POOL_STATUS_CMD="cat \"$file\""
    name="$(basename -s .status $file)"

    if [ ! -f "$file.expected" ]
    then
        fail "exec-zfs - $name missing expected output file"
        continue
    fi

    ./exec-zfs.sh 2>/dev/null | diff - "$file.expected" > /dev/null 2>&1

    if [ $? != 0 ]
    then
        fail "exec-zfs - $name doesn't match expected output"
    else
        pass "exec-zfs - $name"
    fi
done

echo

test_total=$(echo "$pass_total + $fail_total" | bc)

white "[ "

if [ $test_total != 0 ] && [ $test_total == $pass_total ]
then
    green $pass_total
else
    red $pass_total
fi

white " / $test_total ] tests passed"

echo

[ $test_total == 0 ] && exit 1
exit $fail_total
