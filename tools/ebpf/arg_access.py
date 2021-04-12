#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import strftime

# Specify standard block that goes on top of our BPF programs.
bpf_text = """
#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

int probe_uri(struct pt_regs *ctx) {
  char buf[64];
  bpf_probe_read(&buf, sizeof(buf), (void *)PT_REGS_PARM2(ctx));
  bpf_trace_printk("%s\\n", &buf);
  return 0;
}
"""

def arg_access():
    b = BPF(text=bpf_text)

    # Attach a probe for each function that we're tracing.
    b.attach_uprobe(
        name="/home/alexc/work/wiredtiger/build_posix/.libs/libwiredtiger-10.0.0.so",
        sym="__wt_cursor_init",
        fn_name="probe_uri")

    # Print header.
    print("%-9s %-6s %s" % ("TIME", "PID", "URI"))

    # Write URIs that get opened.
    while 1:
        try:
            (task, pid, cpu, flags, ts, msg_b) = b.trace_fields()
            msg = msg_b.decode('utf8')
            print("%-9s %-6d %s" % (strftime("%H:%M:%S"), pid, msg))
        except ValueError:
            continue

arg_access()
