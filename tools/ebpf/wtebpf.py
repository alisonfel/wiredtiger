#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
import argparse
import threading, queue
import logging, time
from latency import calculate_latencies

parser = argparse.ArgumentParser(
    description="Trace WiredTiger with eBPF",
    formatter_class=argparse.RawDescriptionHelpFormatter)

parser.add_argument(metavar="function", nargs="+", dest="functions", help="function(s) to trace")
parser.add_argument("-l", "--lib", type=str, dest="wt_lib", help="WiredTiger library path", required=True)
args = parser.parse_args()

supported_stats = ['frequency','latency','stack']

def frequency_thread(functions, event):
    # datetime.utcnow().isoformat()[:-3]+'Z'
    # {"version":"WiredTiger 10.0.0","localTime":"2021-04-09T02:41:26.000Z","wiredTigerEBPF":{blah}} 
    print("Starting frequency stat thread for functions [%s]" % functions)
    while not event.is_set():
       time.sleep(1)
    print("frequency stat thread exiting")

def stack_thread(functions, event):
    print("Starting stack stat thread for functions [%s]" % functions)
    while not event.is_set():
       time.sleep(1)
    print("stack stat thread exiting")

def latency_thread(functions, event):
    print("Starting latency stat thread for functions [%s]" % functions)
    while not event.is_set():
       time.sleep(1)
    calculate_latencies(functions[0])
    print("latency stat thread exiting")

stat_config = {}
for func in args.functions:
    # function_name:frequency,latency,stack
    func_items = func.split(":")
    if len(func_items) != 2:
        print('Invalid format: %s' % func)
        print('Usage: function_name:frequency,latency,stack')
        exit(1)
    stat_items = func_items[1].split(',')
    if len(stat_items) == 0:
        print('Invalid Format - function requires statistic: %s' % func)
        print('Usage: function_name:frequency,latency,stack')
        exit(1)
    if not all(i in supported_stats for i in stat_items):
        print('Invalid Format - Invalid statistic specified: %s' % func)
        print('Usage: function_name:frequency,latency,stack')
        exit(1)

    for stat in stat_items:
        if stat not in stat_config:
            stat_config[stat] = []
        stat_config[stat].append(func_items[0])

stat_threads = []
exit_event = threading.Event()
for stat,functions in stat_config.items():
    target_function = None
    if stat == 'frequency':
        target_function = frequency_thread
    elif stat == 'latency':
        target_function = latency_thread
    else:
        target_function = stack_thread
    stat_thread = threading.Thread(target=target_function, args=(functions,exit_event,))
    stat_threads.append(stat_thread)
    stat_thread.start()

try:
    while True:
        pass
except KeyboardInterrupt:
    exit_event.set()

for thread in stat_threads:
    thread.join()
