#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from datetime import datetime
import threading, os
import json, collections, time

log_interval = 0.5 # 0.5 seconds
age_multiplier = 1000000000 # ns to seconds

class Session(object):
    def __init__(self, sid, config, timestamp, addr):
        self.config = config
        self.timestamp = timestamp
        self.sid = sid
        self.addr = addr

class Txn(object):
    def __init__(self, sid, config, timestamp):
        self.config = config
        self.timestamp = timestamp
        self.sid = sid

class SessionTrace():
    def __init__(self, wt_lib):
        # Initialise BPF program
        src = os.path.dirname(__file__) + '/wt_sessiontrace.c'
        self.b = BPF(src_file=src)
        self.session_counter = 0

        # Tracked session
        self.session_info = {}
        self.txn_info = {}

        # Trace active sessions
        self.b.attach_uprobe(name=wt_lib, sym='__wt_open_session', fn_name='session_create_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_open_session', fn_name='session_create_ret')
        self.b.attach_uretprobe(name=wt_lib, sym='__wt_session_close_internal', fn_name='wt_session_close')

        # Trace active txns
        self.b.attach_uprobe(name=wt_lib, sym='__session_begin_transaction', fn_name='wt_begin_transaction_enter')
        self.b.attach_uretprobe(name=wt_lib, sym='__session_begin_transaction', fn_name='wt_begin_transaction_ret')
        self.b.attach_uretprobe(name=wt_lib, sym='__session_commit_transaction', fn_name='wt_transaction_commit')
        self.b.attach_uretprobe(name=wt_lib, sym='__session_rollback_transaction', fn_name='wt_transaction_rollback')

        # Create our memtrace file
        script_dir = os.path.dirname(__file__)
        trace_filename = script_dir + '/../../stats/sessiontrace.stat'
        os.makedirs(os.path.dirname(trace_filename), exist_ok=True)
        self.trace_out = open(trace_filename,'w')

    def log_current_sessions(self, trace_log):
        sessions = self.b["sessions"]
        curr_session_info = {}
        for _, info in sessions.items():
            session = None
            if info.session_addr in self.session_info:
                session = self.session_info[info.session_addr]
            else:
                session = Session(self.session_counter, info.config, info.timestamp_ns, info.session_addr)
                self.session_counter += 1
                self.session_info[info.session_addr] = session
            curr_session_info[info.session_addr] = session

        active_session_keys = self.session_info.keys() & curr_session_info.keys()
        self.session_info = {k: self.session_info[k] for k in active_session_keys }

        txns = self.b["txns"]
        curr_txn_info = {}
        for _, info in txns.items():
            session_id = -1
            txn = None
            # Find the txns corresponding session
            if info.session in self.session_info:
                session = self.session_info[info.session]
                session_id = session.sid

            if session_id == -1:
                # Can't match txn. Print txn and continue
                print("Transaction found with no matching session:")
                print("\tSession Addr: %s\n\tConfig: \"%s\"\n" % (hex(info.session), info.config.decode('utf8')))
                continue

            if info.session in self.txn_info:
                txn = self.txn_info[info.session]
            else:
                txn = Txn(session_id, info.config, info.timestamp_ns)
                self.txn_info[info.session] = txn
            curr_txn_info[info.session] = txn

        active_txn_keys = self.txn_info.keys() & curr_txn_info.keys()
        self.txn_info = {k: self.txn_info[k] for k in active_txn_keys }

        if(len(self.session_info.values()) >= 1):
            log_output = ""
            log_output += "[%s] Active Sessions:\n" % (datetime.now().strftime("%H:%M:%S"))
            session_order = sorted(self.session_info.values(),key=lambda s: s.sid)
            for session in session_order:
                log_output += "\tSession %d: \n" % session.sid
                log_output += "\t\tConfig: \"%s\"\n" % session.config.decode('utf8')
                log_output += "\t\tAge: %f (secs) \n" %((BPF.monotonic_time() - session.timestamp)/age_multiplier)
                if session.addr in self.txn_info:
                    s_txn = self.txn_info[session.addr]
                    log_output += "\t\tActive Transaction:\n\t\t\tConfig: \"%s\"\n\t\t\tAge: %f (secs) \n" % (
                            s_txn.config.decode('utf8'),
                            (BPF.monotonic_time() - txn.timestamp)/age_multiplier)
            trace_log.send(log_output.encode())
            self.trace_out.write(log_output)

    def enter_trace(self, exit_event, trace_log):
        log_time = time.time()
        while not exit_event.is_set():
            time.sleep(log_interval)
            self.log_current_sessions(trace_log)

def customTraceThread(functions, wt_lib, exit_event, sock):
    sessionTracer = SessionTrace(wt_lib)
    sessionTracer.enter_trace(exit_event, sock)
