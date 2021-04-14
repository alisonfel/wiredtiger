#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from frequency import frequency_thread
import argparse
import threading, queue
import logging, time
from latency import calculate_latencies
import stat_stacktrace

parser = argparse.ArgumentParser(
    description="Trace WiredTiger with eBPF",
    formatter_class=argparse.RawDescriptionHelpFormatter)

supported_stats = ['frequency','latency','stack']

parser.add_argument(metavar="function", nargs="+", dest="functions", help="function(s) to trace")
parser.add_argument("-l", "--lib", type=str, dest="wt_lib", help="WiredTiger library path", required=True)
parser.add_argument("-s", "--stat", choices=supported_stats, dest="stat", help="stat to track", required=True)
args = parser.parse_args()

def latency_thread(functions, wt_lib, event):
    print("Starting latency stat thread for functions [%s]" % functions)
    while not event.is_set():
       time.sleep(1)
    calculate_latencies(functions[0])
    print("latency stat thread exiting")

exit_event = threading.Event()
target_function = None
if args.stat == 'frequency':
    target_function = frequency_thread
elif args.stat == 'latency':
    target_function = latency_thread
else:
    target_function = stat_stacktrace.stackTraceThread
stat_thread = threading.Thread(target=target_function, args=(args.functions,args.wt_lib,exit_event,))
stat_thread.start()

try:
    while True:
        pass
except KeyboardInterrupt:
    exit_event.set()

stat_thread.join()
