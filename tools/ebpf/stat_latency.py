#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from datetime import datetime
from time import sleep
import threading, os
import json
import math
import time

min_duration_ns = 10000
nbuckets = 20

latency_bucket_labels = ["0-1", "2-3", "4-7", "8-15", "16-31",
                        "32-63", "64-127", "128-255", "256-511", "512-1023",
                        "1024-2047", "2048-4095", "4096-8191", "8192-16383", "16384-32767",
                        "32768-65535", "65536-131071", "131072-262143", "262144-524287", "524288+"]

class LatencyTrace():
    def __init__(self, wt_lib, functions):
        self.functions = functions
        self.buckets = {}
        self.json_file_contents = ""

        bpf_text = ""
        script_dir = os.path.dirname(__file__)
        with open(script_dir + '/ebpf_c/stack_ebpf.c') as f:
            bpf_text = f.read()

        for i in range(len(functions)):
            bpf_text += """
            int trace_%d(struct pt_regs *ctx) {
                return trace_entry(ctx, %d);
            }
            """ % (i, i)
        bpf_text = bpf_text.replace('DURATION_NS', str(min_duration_ns))
        self.b = BPF(text=bpf_text, cflags=["-include", script_dir + "/ebpf_c/include/asm_redef.h"])


        for i, func in enumerate(functions):
            self.buckets[func] = [0] * nbuckets
            self.b.attach_uprobe(name=wt_lib, sym=func, fn_name="trace_%d" % i)
            self.b.attach_uretprobe(name=wt_lib, sym=func, fn_name="trace_return")

        # Create our stack file
        latency_filename = script_dir + '/stats/latency.stat'
        os.makedirs(os.path.dirname(latency_filename), exist_ok=True)
        self.latency_out = open(latency_filename,'w')

    def log_latency_event(self, event):
        func_name = self.functions[event.id]
        func_latency = event.duration_ns
        latency_bucket = int(math.log2(func_latency))

        if latency_bucket >= nbuckets:
            latency_bucket = nbuckets - 1

        self.buckets[func_name][latency_bucket] += 1

        latency_data = {}
        for i in range(nbuckets):
            latency_data[latency_bucket_labels[i]] = self.buckets[func_name][i]

        json_data = {}
        json_data["version"] = "WiredTiger 10.0.0: (March 18, 2020)"
        json_data["localTime"] = datetime.utcnow().isoformat()[:-3]+"Z"
        json_data["wiredTigerEBPF"] = {}
        json_data["wiredTigerEBPF"]["funcName"] = func_name
        json_data["wiredTigerEBPF"]["funcLatencies"] = latency_data

        json_txt = json.dumps(json_data)
        self.json_file_contents = self.json_file_contents + json_txt

    def log_event(self, cpu, data, size):
        event = self.b["events"].event(data)
        self.log_latency_event(event)

    def enter_trace(self, exit_event, sock):
        log_time = time.time()
        self.b["events"].open_perf_buffer(self.log_event, page_cnt=64)
        while not exit_event.is_set():
            # Periodically exit perf_buffer_poll (every ms to see if we need to exit)
            self.b.perf_buffer_poll(timeout=1)
            self.latency_out.write(self.json_file_contents)
            self.latency_out.write('\n')
            if(time.time()-log_time >= 1):
                sock.send(self.json_file_contents.encode())
                log_time = time.time()
        self.latency_out.close()

def latencyTraceThread(functions, wt_lib, exit_event, sock):
    latencyTracer = LatencyTrace(wt_lib, functions)
    latencyTracer.enter_trace(exit_event, sock)
