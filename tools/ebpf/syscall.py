#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import strftime

# Our BPF program.
bpf_text = """
#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

int probe_disk_read(struct pt_regs *ctx) {
  char buf[256] = {};
  bpf_probe_read(&buf, sizeof(buf), (void *)PT_REGS_PARM2(ctx));
  bpf_trace_printk("%s\\n", &buf);
  return 0;
}
"""

# Print what gets written to the buffer by vfs_read.
def syscall():
    b = BPF(text=bpf_text)

    b.attach_kretprobe(
        event="vfs_read",
        fn_name="probe_disk_read")

    # Write disk reads that occur along with their size.
    while 1:
        try:
            (task, pid, cpu, flags, ts, msg_b) = b.trace_fields()
            msg = msg_b.decode("utf8")
            print(msg)
        except ValueError:
            continue

syscall()
