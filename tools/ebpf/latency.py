 #!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import sleep, strftime
import argparse
import json
import signal
from datetime import datetime

# This functionality is heavily based off a program already in the BCC repo.
# https://github.com/iovisor/bcc/blob/master/tools/funclatency.py

def calculate_latencies(function_pattern):
    # parser = argparse.ArgumentParser(
    #     description="Function Latency Statistics",
    #     formatter_class=argparse.RawDescriptionHelpFormatter)
    # parser.add_argument("pattern", help="search expression for functions")
    # args = parser.parse_args()

    # pattern = args.pattern
    interval = 99999999
    # function_pattern = pattern

    # define BPF program
    bpf_header  = """
    #ifdef asm_inline
    #undef asm_inline
    #define asm_inline asm
    #endif
    """

    bpf_text = """
    #include <uapi/linux/ptrace.h>
    typedef struct ip_pid {
        u64 ip;
        u64 pid;
    } ip_pid_t;
    typedef struct hist_key {
        ip_pid_t key;
        u64 slot;
    } hist_key_t;
    BPF_HASH(start, u32);
    BPF_ARRAY(avg, u64, 2);
    BPF_ARRAY(latencies, u64, 20);
    STORAGE
    int trace_func_entry(struct pt_regs *ctx)
    {
        u64 pid_tgid = bpf_get_current_pid_tgid();
        u32 pid = pid_tgid;
        u32 tgid = pid_tgid >> 32;
        u64 ts = bpf_ktime_get_ns();
        FILTER
        ENTRYSTORE
        start.update(&pid, &ts);
        return 0;
    }
    int trace_func_return(struct pt_regs *ctx)
    {
        u64 *tsp, delta;
        u64 pid_tgid = bpf_get_current_pid_tgid();
        u32 pid = pid_tgid;
        u32 tgid = pid_tgid >> 32;
        // calculate delta time
        tsp = start.lookup(&pid);
        if (tsp == 0) {
            return 0;   // missed start
        }
        delta = bpf_ktime_get_ns() - *tsp;
        start.delete(&pid);
        u32 lat = 0;
        u32 cnt = 1;
        u64 *sum = avg.lookup(&lat);
        if (sum) lock_xadd(sum, delta);
        u64 *cnts = avg.lookup(&cnt);
        if (cnts) lock_xadd(cnts, 1);
        // store as histogram
        STORE

        // Manually split into 20 time buckets.
        int latbucket = bpf_log2l(delta);
        if (latbucket > 19) {
            latbucket = 19;
        }
        u64 *latcount = latencies.lookup(&latbucket);
        if (!latcount) {
            return 0;
        }
        (*latcount)++;
        return 0;
    }
    """

    # code substitutions 
    bpf_text = bpf_text.replace('FILTER', '')
    bpf_text = bpf_text.replace('STORAGE', 'BPF_HISTOGRAM(dist);')
    bpf_text = bpf_text.replace('ENTRYSTORE', '')
    bpf_text = bpf_text.replace('STORE',
        'dist.increment(bpf_log2l(delta));')

    # signal handler
    def signal_ignore(signal, frame):
        print()

    def export_to_json(pattern, latency_counts, latency_bucket_labels, avg, total):
        latency_data = {}
        for i in range(len(latency_counts)):
            latency_data[latency_bucket_labels[i]] = latency_counts[i]
        
        latency_buckets = json.dumps(latency_data)
        current_time = datetime.utcnow().isoformat()[:-3]+'Z'

        data = {
            "version" : "WiredTiger 10.0.0",
            "localTime": current_time,
            "wiredTigerEBPF" : {
                "function_name": pattern,
                "bucket_counts": latency_buckets,
                "avg_latency": avg,
                "total_latency": total
            }
        }

        print(data)

        with open('latency.stat', 'w') as outfile:
            json.dump(data, outfile)

    # load BPF program
    b = BPF(text=bpf_header + bpf_text)

    # attach probes
    library = "/home/ubuntu/work/wiredtiger/build_posix/.libs/libwiredtiger-10.0.0.so"

    b.attach_uprobe(name=library, sym_re=function_pattern, fn_name="trace_func_entry",
                    pid=-1)
    b.attach_uretprobe(name=library, sym_re=function_pattern,
                        fn_name="trace_func_return", pid=-1)
    matched = b.num_open_uprobes()

    if matched == 0:
        print("0 functions matched by \"%s\". Exiting." % function_pattern)
        exit()

    # header
    print("Tracing %d functions for \"%s\"... Hit Ctrl-C to end." %
        (matched / 2, function_pattern))

    # output
    def print_section(key):
        if not library:
            return BPF.sym(key[0], -1)
        else:
            return "%s [%d]" % (BPF.sym(key[0], key[1]), key[1])

    exiting = 0 if interval else 1
    seconds = 0
    dist = b.get_table("dist")

    while (1):
        try:
            sleep(interval)
            seconds += interval
        except KeyboardInterrupt:
            exiting = 1
            # as cleanup can take many seconds, trap Ctrl-C:
            signal.signal(signal.SIGINT, signal_ignore)

        print()

        dist.print_log2_hist()
        dist.clear()

        total  = b['avg'][0].value
        counts = b['avg'][1].value

        print()
        print("PRINTING LATENCY STATISTICS")
        latency_counts = []
        latency_bucket_labels = ["0-1", "2-3", "4-7", "8-15", "16-31",
                                "32-63", "64-127", "128-255", "256-511", "512-1023", 
                                "1024-2047", "2048-4095", "4096-8191", "8192-16383", "16384-32767", 
                                "32768-65535", "65536-131071", "131072-262143", "262144-524287", "524288+"]

        for i in range(20):
            latency_counts.append(b['latencies'][i].value)
            print(b['latencies'][i].value, latency_bucket_labels[i] + " secs")
        
        if counts > 0:
            avg = total/counts
            print("\navg = %ld nsecs, total: %ld nsecs, count: %ld\n" %(total/counts, total, counts))

        if exiting:
            print("Detaching...")
            export_to_json(function_pattern, latency_counts, latency_bucket_labels, avg, total)
            exit()

function_string = "__wt_open_cursor"
calculate_latencies(function_string)