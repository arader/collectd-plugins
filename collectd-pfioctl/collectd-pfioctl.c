/*
 * Copyright (c) 2019 Andrew Rader <ardr@outlook.com>
 *  Original work by Landon, modified by Andrew to output
 *  in `collectd` PUTVAL format
 * Copyright (c) 2005 Landon J. Fuller <landonf@opendarwin.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright owner nor the names of contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <time.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <stdlib.h>

#include <fcntl.h>

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <net/if.h>
#include <net/pfvar.h>

#include <errno.h>
#include <err.h>

const char pf_device[] = "/dev/pf";

enum { IN, OUT };
enum { IPV4, IPV6 };
enum { PASS, BLOCK };

void *xmalloc(size_t size) {
    void *ptr = malloc(size);
    if (!ptr) {
        err(1, "malloc failed!");
    }
    return (ptr);
}

void *xrealloc(void *ptr, size_t size) {
    ptr = realloc(ptr, size);
    if (!ptr) {
        err(1, "realloc failed!");
    }
    return (ptr);
}

void print_iface_stats(char* hostname, int interval, long time, struct pfi_kif *iface) {
    u_int64_t ipv4_in_pass, ipv4_in_block;
    u_int64_t ipv6_in_pass, ipv6_in_block;
    u_int64_t ipv4_out_pass, ipv4_out_block;
    u_int64_t ipv6_out_pass, ipv6_out_block;
    unsigned long long total_in_pass, total_in_block;
    unsigned long long total_out_pass, total_out_block;
    unsigned long long total_in, total_out;
    
    ipv4_in_pass = iface->pfik_bytes[IPV4][IN][PASS];
    ipv6_in_pass = iface->pfik_bytes[IPV6][IN][PASS];
    total_in_pass = ipv4_in_pass + ipv6_in_pass;

    ipv4_in_block = iface->pfik_bytes[IPV4][IN][BLOCK];
    ipv6_in_block = iface->pfik_bytes[IPV6][IN][BLOCK];
    total_in_block = ipv4_in_block + ipv6_in_block;

    total_in = total_in_pass + total_in_block;

    ipv4_out_pass = iface->pfik_bytes[IPV4][OUT][PASS];
    ipv6_out_pass = iface->pfik_bytes[IPV6][OUT][PASS];
    total_out_pass = ipv4_out_pass + ipv6_out_pass;

    ipv4_out_block = iface->pfik_bytes[IPV4][OUT][BLOCK];
    ipv6_out_block = iface->pfik_bytes[IPV6][OUT][BLOCK];
    total_out_block = ipv4_out_block + ipv6_out_block;

    total_out = total_out_pass + total_out_block;

    if (total_in > 0 || total_out > 0)
    {
        printf("PUTVAL %s/pfioctl-%s/if_packets-passed interval=%u %lu:%llu:%llu\n",
            hostname,
            iface->pfik_name,
            interval,
            time,
            total_in_pass,
            total_out_pass);

        printf("PUTVAL %s/pfioctl-%s/if_packets-blocked interval=%u %lu:%llu:%llu\n",
            hostname,
            iface->pfik_name,
            interval,
            time,
            total_in_block,
            total_out_block);
     }
}

int get_pf_ifaces(int dev, struct pfi_kif *buffer, int *numentries, int flags) {
    struct pfioc_iface io;

    bzero(&io, sizeof(io));    

    /* Set up our request structure */
    io.pfiio_buffer = buffer;    
    io.pfiio_esize = sizeof(*buffer);
    io.pfiio_size = *numentries;
    io.pfiio_flags = flags;
    
    if (ioctl(dev, DIOCIGETIFACES, &io) == -1) {
        warn("DIOCIGETIFACES failed:");
        return (-1);
    }

    /* Provide the number of entries to the caller */    
    *numentries = io.pfiio_size;
    
    return (0);
}

int main(int argc, char *argv[]) {
    struct pfi_kif *ifaces = NULL;
    int numentries = 0;
    int dev, i;
    char* hostname = getenv("COLLECTD_HOSTNAME");
    char* a_interval = getenv("COLLECTD_INTERVAL");
    int interval = 10;

    if (hostname == NULL) {
        hostname = xmalloc(sizeof(char) * 255);
        gethostname(hostname, 255);
    }

    if (a_interval != NULL) {
        interval = strtol(a_interval, (char **)NULL, 10);
        interval = interval > 0 ? interval : 10;
    }

    dev = open(pf_device, O_RDONLY);
    if (dev < 0) {
        err(1, "Opening %s failed", pf_device);
    }

    while (1) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);

        /* Get the number of pfi_kif structs to be returned and malloc the required memory */
        if(get_pf_ifaces(dev, ifaces, &numentries, /*PFI_FLAG_INSTANCE*/ 0) < 0)
            errx(1, "get_pf_ifaces() failed");
            
        ifaces = xmalloc(sizeof(struct pfi_kif) * numentries);
    
        /*
         * Record the previous number of entries specified.
         * If more are required after the second call, we'll have to realloc
         * our ifaces buffer.
         */
        i = numentries;
        while (1) {    
            if(get_pf_ifaces(dev, ifaces, &numentries, /*PFI_FLAG_INSTANCE*/ 0) < 0)
                errx(1, "get_pf_ifaces() failed");
    
            if (i < numentries) {
                /*
                 * An interface was added prior to this call, but after the last
                 * get_pf_ifaces call.
                 * Allocate more space and loop through again.
                 */
                i = numentries;
                ifaces = xrealloc(ifaces, sizeof(struct pfi_kif) * numentries);
            } else {
                /* The same number or fewer entries were returned */
                break;
            }
        }
    
        for(i = 0; i < numentries; i++)
            print_iface_stats(hostname, interval, ts.tv_sec, &ifaces[i]);

        fflush(stdout);

        free(ifaces);
        ifaces = NULL;
        numentries = 0;
        sleep(interval);
    }

    close(dev);
    exit (0);
}
