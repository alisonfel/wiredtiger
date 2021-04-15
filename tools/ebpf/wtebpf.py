#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
import argparse
import threading, queue
import logging, time
import stat_frequency, stat_latency, stat_stacktrace
import socket

parser = argparse.ArgumentParser(
    description="Trace WiredTiger with eBPF",
    formatter_class=argparse.RawDescriptionHelpFormatter)

supported_stats = ['frequency','latency','stack']

parser.add_argument(metavar="function", nargs="+", dest="functions", help="function(s) to trace")
parser.add_argument("-l", "--lib", type=str, dest="wt_lib", help="WiredTiger library path", required=True)
parser.add_argument("-s", "--stat", choices=supported_stats, dest="stat", help="stat to track", required=True)
parser.add_argument("-a", "--address", type=str, dest="address", help="Host address", required=True)
parser.add_argument("-p", "--port", type=int, dest="port", help="Host port", required=True)
args = parser.parse_args()

exit_event = threading.Event()
target_function = None
if args.stat == 'frequency':
    target_function = stat_frequency.frequencyThread
elif args.stat == 'latency':
    target_function = stat_latency.latencyTraceThread
else:
    target_function = stat_stacktrace.stackTraceThread

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.connect((args.address, args.port))

stat_thread = threading.Thread(target=target_function, args=(args.functions,args.wt_lib,exit_event,sock,))
stat_thread.start()

try:
    while True:
        pass
except KeyboardInterrupt:
    exit_event.set()

stat_thread.join()
