#!/usr/bin/python

from __future__ import print_function
from bcc import BPF, USDT
import sys

bpf_text = """
#include <uapi/linux/ptrace.h>

BPF_PERF_OUTPUT(events);

struct open_cursor {
    char uri[300];
    u64 timestamp;
};

int do_open_cursor(struct pt_regs *ctx) {
    uint64_t addr;
    struct open_cursor oc = {0};

    oc.timestamp = bpf_ktime_get_ns();
    bpf_usdt_readarg(1, ctx, &addr);
    bpf_probe_read(&oc.uri, sizeof(oc.uri), (void *)addr);
    events.perf_submit(ctx, &oc, sizeof(oc));
    return 0;
};
"""

def print_event(cpu, data, size):
    event = b["events"].event(data)
    print("{0}: Opened cursor at uri {1}".format(
    event.timestamp, event.uri))

u = USDT(path=sys.argv[1])
u.enable_probe(probe="wt_open_cursor", fn_name="do_open_cursor")
b = BPF(text=bpf_text, usdt_contexts=[u], cflags=["-include","../include/asm_redef.h"])
b["events"].open_perf_buffer(print_event)

while 1:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
