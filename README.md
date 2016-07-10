# arader's collectd plugins #
Herein contains a few collectd plugins that I've found useful.

Most, if not all, will be specific to FreeBSD based systems.

## exec-temps.sh ##
Collects the core temp readings of the system's CPUs

### Setup ###
Require's an Intel based machine that supports `coretemp(4)`. First,
add the following to `/boot/loader.conf`
```
coretemp_load="YES"
```
Place `exec-temps.sh` somewhere that `collectd` can read it. Modify
your **collectd.conf** to include the following:
```
LoadPlugin exec

<Plugin exec>
    Exec "nobody" "/usr/local/lib/collectd/exec-temps.sh"
</Plugin>
```

## exec-zfs.sh ##
