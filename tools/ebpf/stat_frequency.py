#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import sleep, strftime
import datetime, json, threading

# tetsuo-cpp: The approach is heavily based off a program already in the BCC repo.
# Use this: https://github.com/iovisor/bcc/blob/master/tools/funccount.py

# Specify standard block that goes on top of our BPF programs.
bpf_header  = """
#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>
"""

def _get_probe_name(function_name):
    return 'probe_{}'.format(function_name)

def _generate_bpf_source(functions):
    count_array_text = """
BPF_ARRAY(counts, u64, {});
""".format(len(functions))

    function_text = str()
    loc = 0
    for f in functions:
        new_function_text = """
int PROBE_FUNCTION(void *ctx) {
  int loc = LOCATION;
  u64 *val = counts.lookup(&loc);
  if (!val) {
    return 0; // Should never happen.
  }
  (*val)++;
  return 0;
}
        """
        new_function_text = new_function_text.replace("PROBE_FUNCTION", _get_probe_name(f))
        new_function_text = new_function_text.replace("LOCATION", str(loc))
        function_text += new_function_text
        loc += 1
    return bpf_header + count_array_text + function_text

def _clear_count_array(bpf, array_size):
    counts = bpf["counts"]
    for loc in range(0, array_size):
        counts[counts.Key(loc)] = counts.Leaf()

def _construct_json_obj(bpf, functions):
    json_obj = {}
    json_obj["version"] = "WiredTiger 10.0.0: (March 18, 2020)"
    json_obj["localTime"] = datetime.datetime.utcnow().isoformat()[:-3] + "Z"

    stats_obj = {}
    json_obj["wiredTigerEBPF"] = {}
    json_obj["wiredTigerEBPF"]["frequency"] = stats_obj

    bpf_counts = bpf["counts"]
    for k, v in bpf_counts.items():
        function_name = functions[k.value]
        stats_obj[function_name] = v.value

    return json_obj

def frequencyThread(functions, wt_lib, event, sock):
    assert(isinstance(functions, list))
    assert(isinstance(wt_lib, str))
    assert(isinstance(event, threading.Event))

    bpf_text = _generate_bpf_source(functions)

    b = BPF(text=bpf_text)

    # Initialise the array to 0 before we start counting.
    _clear_count_array(b, len(functions))

    # Attach a probe for each function that we're tracing.
    for f in functions:
        b.attach_uretprobe(
            name=wt_lib,
            sym=f,
            fn_name=_get_probe_name(f))

    # We should expose these as options at some point.
    stat_file_name = "frequency.stat"
    interval = 1

    stat_file = open(stat_file_name, "w")

    # Loop and dump the stats as JSON every X seconds.
    while not event.is_set():
        json_obj = _construct_json_obj(b, functions)
        json_txt = json.dumps(json_obj)
        sock.send(json_txt.encode())
        stat_file.write(json_txt)
        stat_file.write("\n")
        sleep(interval)

    stat_file.close()
