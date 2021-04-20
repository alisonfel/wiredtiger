#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from datetime import datetime
import threading, os
import json, collections, time

# Minimum latency threshold required to report stack
mem_log_interval = 1 # 1 seconds
num_stacks = 5 # 1 seconds
min_age_ns = 1e6 * 500 # Prune allocations younger than 5ms

class Allocation(object):
    def __init__(self, stack, size):
        self.stack = stack
        self.count = 1
        self.size = size

    def update(self, size):
        self.count += 1
        self.size += size

class MemTrace():
    def __init__(self, wt_lib, functions):
        self.functions = functions
        self.traces = collections.OrderedDict()
        self.traces_count = {}

        # Initialise BPF program
        src = os.path.dirname(__file__) + '/wt_memtrace.c'
        self.b = BPF(src_file=src)

        self.b.attach_uprobe(name=wt_lib, sym='__wt_malloc', fn_name='wt_malloc_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_malloc', fn_name='wt_malloc_exit')
        self.b.attach_uprobe(name=wt_lib, sym='__wt_calloc', fn_name='wt_calloc_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_calloc', fn_name='wt_calloc_exit')
        self.b.attach_uprobe(name=wt_lib, sym='__wt_realloc', fn_name='wt_realloc_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_realloc', fn_name='wt_realloc_exit')
        self.b.attach_uprobe(name=wt_lib, sym='__wt_realloc_noclear', fn_name='wt_realloc_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_realloc_noclear', fn_name='wt_realloc_exit')
        self.b.attach_uprobe(name=wt_lib, sym='__wt_free_int', fn_name='wt_free_enter')

        # Create our memtrace file
        script_dir = os.path.dirname(__file__)
        trace_filename = script_dir + '/../../stats/memstrace.stat'
        os.makedirs(os.path.dirname(trace_filename), exist_ok=True)
        self.trace_out = open(trace_filename,'w')

    def log_outstanding_allocations(self, trace_log):
        alloc_info = {}
        allocs = self.b["allocs"]
        stack_traces = self.b["stack_traces"]
        for address, info in allocs.items():
            if BPF.monotonic_time() - min_age_ns < info.timestamp_ns:
                continue
            if info.stack_id < 0:
                continue
            if info.stack_id in alloc_info:
                alloc_info[info.stack_id].update(info.size)
            else:
                stack = list(stack_traces.walk(info.stack_id))
                combined = []
                symbols_found = False
                for addr in stack:
                    sym = self.b.sym(addr, info.tgid_pid, show_offset=True)
                    sym = sym.decode('utf8')
                    if ("[unknown]" not in sym):
                        symbols_found = True
                    combined.append(self.b.sym(addr, info.tgid_pid, show_offset=True))
                if symbols_found:
                    alloc_info[info.stack_id] = Allocation(combined, info.size)

        if(len(alloc_info.values()) >= 1):
            log_output = ""
            log_output += "[%s] Top %d stacks with outstanding allocations:\n" % (datetime.now().strftime("%H:%M:%S"), min(len(alloc_info.values()), num_stacks))
            to_show = sorted(alloc_info.values(),key=lambda a: a.size)[-num_stacks:]
            for alloc in to_show:
                log_output += "\t%d bytes in %d allocations from stack\n\t\t%s\n" % (alloc.size, alloc.count, b"\n\t\t".join(alloc.stack).decode("ascii"))
            trace_log.send(log_output.encode())
            self.trace_out.write(log_output)

    def enter_trace(self, exit_event, trace_log):
        log_time = time.time()
        while not exit_event.is_set():
            self.log_outstanding_allocations(trace_log)
            time.sleep(mem_log_interval)

def customTraceThread(functions, wt_lib, exit_event, sock):
    memTracer = MemTrace(wt_lib, functions)
    memTracer.enter_trace(exit_event, sock)
