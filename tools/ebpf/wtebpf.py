#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
import argparse
import threading, queue
import logging, time
import stat_frequency, stat_latency, stat_stacktrace
import socket, os
import importlib.util

parser = argparse.ArgumentParser(
    description="Trace WiredTiger with eBPF",
    formatter_class=argparse.RawDescriptionHelpFormatter)

supported_stats = ['frequency','latency','stack']

parser.add_argument(metavar="function", nargs="*", dest="functions", help="function(s) to trace")
parser.add_argument("-l", "--lib", type=str, dest="wt_lib", help="WiredTiger library path", required=True)
parser.add_argument("-s", "--stat", choices=supported_stats, dest="stat", help="stat to track")
parser.add_argument("-a", "--address", type=str, dest="address", help="Host address", required=True)
parser.add_argument("-p", "--port", type=int, dest="port", help="Host port", required=True)
parser.add_argument("-c", "--custom", type=str, dest="custom_tracer", help="Custom Tracers")
args = parser.parse_args()

exit_event = threading.Event()
if((args.functions and not args.stat) or (not args.functions and args.stat)):
    print("Both a statistic to track and a set functions need to be given")
    parser.print_help()
    exit(1)

if(args.stat and args.custom_tracer):
    print("Can't both pass a statistic to track and a set of custom tracers")
    parser.print_help()
    exit(1)

tracer_thread = None
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.connect((args.address, args.port))

if(args.functions and args.stat and not args.custom_tracer):
    target_function = None
    if args.stat == 'frequency':
        target_function = stat_frequency.frequencyThread
    elif args.stat == 'latency':
        target_function = stat_latency.latencyTraceThread
    else:
        target_function = stat_stacktrace.stackTraceThread

    tracer_thread = threading.Thread(target=target_function, args=(args.functions,args.wt_lib,exit_event,sock,))
    tracer_thread.start()

script_dir = os.path.dirname(os.path.realpath(__file__))
if(args.custom_tracer and not args.functions):
    tracer = args.custom_tracer
    tracer_path = 'custom_wt_ebpf/' + tracer + "/" + tracer + ".py"
    if not os.path.isfile(script_dir + "/" + tracer_path):
        print("Custom tracer not found: " + script_dir + "/" + tracer_path)
        exit(1)
    else:
        spec = importlib.util.spec_from_file_location("module.name", script_dir + "/" + tracer_path)
        tracer_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tracer_module)
        tracer_thread = threading.Thread(target=tracer_module.customTraceThread, args=(args.functions,args.wt_lib,exit_event,sock,))
        tracer_thread.start()

try:
    while True:
        pass
except KeyboardInterrupt:
    exit_event.set()

tracer_thread.join()
