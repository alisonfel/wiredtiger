#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from datetime import datetime
import threading, os
import json, collections, time

# Minimum latency threshold required to report stack
min_duration_ns = 10000
time_multiplier = 1000000 # ms

class StackTrace():
    def __init__(self, wt_lib, functions, bpf_lock):
        self.functions = functions
        self.traces = collections.OrderedDict()
        self.traces_count = {}
        # Initialise BPF program
        bpf_text = ""
        with open('ebpf_c/stack_ebpf.c') as f:
            bpf_text = f.read()

        for i in range(len(functions)):
            bpf_text += """
            int trace_%d(struct pt_regs *ctx) {
                return trace_entry(ctx, %d);
            }
            """ % (i, i)
        bpf_text = bpf_text.replace('DURATION_NS', str(min_duration_ns))
        with bpf_lock:
            self.b = BPF(text=bpf_text, cflags=["-include","ebpf_c/include/asm_redef.h"])

        # Initialise our function probes
        for i, func in enumerate(functions):
            self.b.attach_uprobe(name=wt_lib, sym=func, fn_name="trace_%d" % i)
            self.b.attach_uretprobe(name=wt_lib, sym=func, fn_name="trace_return")

        # Create our stack file
        stack_filename = 'stats/stacktrace.stack'
        os.makedirs(os.path.dirname(stack_filename), exist_ok=True)
        self.stack_out = open(stack_filename,'w')
        self.stack_out.write('{}\n'.format('#format timestamp;count;stack-id'))

    def log_csv_stack_event(self, event):
        user_stack = []
        stack_traces = self.b.get_table("stacks")
        timestamp = time.time()

        if event.user_stack_id > 0:
            user_stack = stack_traces.walk(event.user_stack_id)

        has_symbols = False
        frames = []
        stack_trace = [self.functions[event.id]]
        for addr in user_stack:
            frames.append(addr)
            sym = self.b.sym(addr, event.tgid_pid, show_offset=True)
            sym = sym.decode("utf-8")
            stack_trace.append(sym)
            if sym != "[unknown]":
                has_symbols = True

        stack_hash = hash(tuple(frames))
        stack_id = 0
        if stack_hash not in self.traces:
            self.traces[stack_hash] = stack_trace
            self.traces_count[stack_hash] = 1
            stack_id = tuple(self.traces.keys()).index(stack_hash)
            self.stack_out.write('{}\n'.format('#stack ' + str(stack_id) + ' ' + ';'.join(stack_trace)))
        else:
            self.traces_count[stack_hash] += 1
            stack_id = tuple(self.traces.keys()).index(stack_hash)

        self.stack_out.write('%.3f;%d;%d\n' % (timestamp, self.traces_count[stack_hash], stack_id))

    def log_event(self, cpu, data, size):
        event = self.b["events"].event(data)
        self.log_csv_stack_event(event)

    def enter_trace(self, exit_event):
        self.b["events"].open_perf_buffer(self.log_event, page_cnt=64)
        while not exit_event.is_set():
            # Periodically exit perf_buffer_poll (every ms to see if we need to exit)
            self.b.perf_buffer_poll(timeout=1)
        self.stack_out.close()

def stackTraceThread(functions, wt_lib, exit_event, bpf_lock):
    stackTracer = StackTrace(wt_lib, functions, bpf_lock)
    stackTracer.enter_trace(exit_event)
