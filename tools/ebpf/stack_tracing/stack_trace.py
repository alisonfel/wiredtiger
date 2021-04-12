#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
import time
import argparse

def time_str(event):
    return "%-10s " % time.strftime("%H:%M:%S")

def args_str(event):
    return str.join(" ", ["0x%x" % arg for arg in event.args[:6]])

def get_stack(event):
    user_stack = []
    stack_traces = b.get_table("stacks")

    if event.user_stack_id > 0:
        user_stack = stack_traces.walk(event.user_stack_id)

    trace = ""
    has_symbols = False
    for addr in user_stack:
        sym = b.sym(addr, event.tgid_pid)
        trace += "\t%s\n" % sym
        if sym.decode() != "[unknown]":
            has_symbols = True
    return (trace, has_symbols)

def print_event(cpu, data, size):
    event = b["events"].event(data)
    trace, has_symbols = get_stack(event)
    if (has_symbols):
        print((time_str(event) + "%-14.14s %-6s %16x %s %s") %
            (event.comm.decode('utf-8', 'replace'), event.tgid_pid >> 32,
             event.retval, args.functions[event.id], args_str(event)))
        print(trace)
        print()

parser = argparse.ArgumentParser(
    description="Trace user function calls.",
    formatter_class=argparse.RawDescriptionHelpFormatter)

parser.add_argument(metavar="function", nargs="+", dest="functions", help="function(s) to trace")
parser.add_argument("-l", "--lib", type=str, dest="wt_lib", help="wt library path", required=True)
args = parser.parse_args()

bpf_text = ""
with open('stack_ebpf.c') as f:
    bpf_text = f.read()

for i in range(len(args.functions)):
    bpf_text += """
int trace_%d(struct pt_regs *ctx) {
    return trace_entry(ctx, %d);
}
""" % (i, i)

b = BPF(text=bpf_text)

for i, func in enumerate(args.functions):
    b.attach_uprobe(name=args.wt_lib, sym=func, fn_name="trace_%d" % i)
    b.attach_uretprobe(name=args.wt_lib, sym=func, fn_name="trace_return")

b["events"].open_perf_buffer(print_event, page_cnt=64)
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
