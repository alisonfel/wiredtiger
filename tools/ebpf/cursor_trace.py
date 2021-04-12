#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import strftime

# load BPF program
bpf_text = """
#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>
int printret(struct pt_regs *ctx) {
    if (!ctx->bx)
        return 0;
    char str[80] = {};
    bpf_probe_read(&str, sizeof(str), (void *)ctx->bx);
    bpf_trace_printk("%s\\n", &str);
    return 0;
};
"""
b = BPF(text=bpf_text)
b.attach_uretprobe(
        name="/home/ubuntu/work/03_skunkworks/ebpf/wiredtiger/build_posix/.libs/libwiredtiger-10.0.0.so",
        sym="__wt_open_cursor",
        fn_name="printret")

# header
print("%-9s %-6s %s" % ("TIME", "PID", "URI"))

# format output
while 1:
    try:
        (task, pid, cpu, flags, ts, msg_b) = b.trace_fields()
        msg = msg_b.decode('utf8')
        print("%-9s %-6d %s" % (strftime("%H:%M:%S"), pid, msg))
    except ValueError:
        continue
