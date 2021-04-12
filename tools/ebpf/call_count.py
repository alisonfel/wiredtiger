#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from time import strftime

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

def get_probe_name(function_name):
    return 'probe_{}'.format(function_name)

def generate_bpf_source(functions):
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
        new_function_text = new_function_text.replace("PROBE_FUNCTION", get_probe_name(f))
        new_function_text = new_function_text.replace("LOCATION", str(loc))
        function_text += new_function_text
        loc += 1
    return bpf_header + count_array_text + function_text

def clear_count_array(bpf, array_size):
    counts = bpf["counts"]
    for loc in range(0, array_size):
        counts[counts.Key(loc)] = counts.Leaf()

def call_count(functions):
    assert(isinstance(functions, list))

    bpf_text = generate_bpf_source(functions)
    print(bpf_text)

    b = BPF(text=bpf_text)

    # Initialise the array to 0 before we start counting.
    clear_count_array(b, len(functions))

    # Attach a probe for each function that we're tracing.
    for f in functions:
        b.attach_uretprobe(
            name="/home/alexc/work/wiredtiger/build_posix/.libs/libwiredtiger-10.0.0.so",
            sym=f,
            fn_name=get_probe_name(f))

    # Just wait.
    try:
        while 1:
            pass
    except KeyboardInterrupt:
        pass

    # Now print out the counts!
    print("%-36s %8s" % ("FUNC", "COUNT"))
    counts = b["counts"]
    for k, v in sorted(counts.items(), key=lambda counts: counts[1].value):
        print("%-36s %8d" % (functions[k.value], v.value))

call_count(["__wt_open_cursor", "__wt_cursor_init"])
