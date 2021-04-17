#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from datetime import datetime
import threading, os
import json, collections, time

class CursorInitTrace():
    def __init__(self, wt_lib, trace_log):
        self.trace_log = trace_log

        script_dir = os.path.dirname(__file__)
        # Initialise BPF program
        src = os.path.dirname(__file__) + '/wt_cursorinit.c'
        self.b = BPF(src_file=src)

        self.b.attach_uprobe(name=wt_lib, sym='__wt_cursor_init', fn_name='probe_cursorinit')

        # Create our cursorinit trace file
        trace_filename = script_dir + '/../../stats/cursorinit.stat'
        os.makedirs(os.path.dirname(trace_filename), exist_ok=True)
        self.trace_out = open(trace_filename,'w')

    def log_event(self, cpu, data, size):
        event = self.b["events"].event(data)
        cursor_trace = "[%s] Cursor opened on uri: %s\n" % (datetime.now().strftime("%H:%M:%S"), event.uri.decode('utf8'))
        self.trace_log.send(cursor_trace.encode())
        self.trace_out.write(cursor_trace)

    def enter_trace(self, exit_event, trace_log):
        self.b["events"].open_perf_buffer(self.log_event, page_cnt=64)
        while not exit_event.is_set():
            self.b.perf_buffer_poll(timeout=1)
        self.trace_out.close()

def customTraceThread(functions, wt_lib, exit_event, sock):
    cursorInitTracer = CursorInitTrace(wt_lib, sock)
    cursorInitTracer.enter_trace(exit_event, sock)
